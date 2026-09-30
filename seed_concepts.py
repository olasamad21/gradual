import os
import sys
import json
import argparse
import re
from datetime import datetime

def validate_payload(data, allow_review=False, commit=False, db=None):
    errors = []
    warnings = []

    if not isinstance(data, dict):
        return ["Root must be a JSON object"], []

    field = data.get("field")
    if not isinstance(field, str) or not field:
        errors.append("Missing or invalid root 'field'")

    concepts = data.get("concepts", [])
    if not isinstance(concepts, list):
        errors.append("'concepts' must be a list")
        concepts = []

    daily_sets = data.get("daily_sets", [])
    if not isinstance(daily_sets, list):
        errors.append("'daily_sets' must be a list")
        daily_sets = []

    defined_slugs = set()
    for i, c in enumerate(concepts):
        if not isinstance(c, dict):
            errors.append(f"Concept at index {i} is not an object")
            continue

        cid = c.get("id", "")
        if not isinstance(cid, str) or not re.match(r'^[a-z0-9\-]+$', cid):
            errors.append(f"Concept at index {i} has invalid or missing slug 'id': '{cid}'")
        else:
            if cid in defined_slugs:
                errors.append(f"Duplicate concept slug: {cid}")
            defined_slugs.add(cid)

        # Type and required field checks
        if not isinstance(c.get("term"), str) or not c.get("term"):
            errors.append(f"Concept '{cid}' missing 'term'")
        if not isinstance(c.get("category"), str) or not c.get("category"):
            errors.append(f"Concept '{cid}' missing 'category'")
        if c.get("level") not in ["beginner", "intermediate", "advanced"]:
            errors.append(f"Concept '{cid}' has invalid 'level'")

        definition = c.get("definition")
        if not isinstance(definition, str) or not definition:
            errors.append(f"Concept '{cid}' missing 'definition'")
        else:
            if '`' in definition:
                errors.append(f"Concept '{cid}' definition contains backticks or code fences")
            
            sentences = len([s for s in re.split(r'[.!?]+', definition) if s.strip()])
            if not (2 <= sentences <= 4):
                warnings.append(f"Concept '{cid}' definition has {sentences} sentences (expected 2-4)")
            
            term = c.get("term", "")
            if term and definition.split()[0].lower().strip('.,!?') == term.split()[0].lower():
                warnings.append(f"Concept '{cid}' definition starts with the term")

        analogy = c.get("analogy")
        if analogy is not None:
            if not isinstance(analogy, str):
                errors.append(f"Concept '{cid}' analogy must be string or null")
            else:
                if '`' in analogy:
                    errors.append(f"Concept '{cid}' analogy contains backticks or code fences")
                if len(analogy.split()) > 40:
                    warnings.append(f"Concept '{cid}' analogy is > 40 words")

        rwe = c.get("real_world_example")
        if not isinstance(rwe, str) or not rwe:
            errors.append(f"Concept '{cid}' missing 'real_world_example'")
        else:
            if '`' in rwe:
                errors.append(f"Concept '{cid}' real_world_example contains backticks or code fences")

        confused = c.get("confused_with")
        if confused is not None and not isinstance(confused, str):
            errors.append(f"Concept '{cid}' confused_with must be string or null")

        related = c.get("related")
        if not isinstance(related, list):
            errors.append(f"Concept '{cid}' 'related' must be a list")
        else:
            if not all(isinstance(r, str) for r in related):
                errors.append(f"Concept '{cid}' 'related' must contain only strings")

        nr = c.get("needs_review")
        if not isinstance(nr, bool):
            errors.append(f"Concept '{cid}' 'needs_review' must be a boolean")
        elif nr and not allow_review:
            errors.append(f"Concept '{cid}' has needs_review: true, but --allow-review not passed")

        quiz = c.get("quiz")
        if not isinstance(quiz, dict):
            errors.append(f"Concept '{cid}' missing or invalid 'quiz'")
        else:
            if not isinstance(quiz.get("question"), str) or not quiz.get("question"):
                errors.append(f"Concept '{cid}' quiz missing 'question'")
            
            options = quiz.get("options")
            if not isinstance(options, list) or len(options) != 4 or not all(isinstance(o, str) and o.strip() for o in options):
                errors.append(f"Concept '{cid}' quiz must have exactly 4 non-empty string options")
            else:
                lens = [len(o) for o in options]
                if max(lens) > min(lens) * 2 and min(lens) > 0:
                    warnings.append(f"Concept '{cid}' quiz options have very different lengths")

            ans = quiz.get("answer_index")
            if not isinstance(ans, int) or not (0 <= ans <= 3):
                errors.append(f"Concept '{cid}' quiz answer_index must be an int 0-3")
            
            exp = quiz.get("explanation")
            if not isinstance(exp, str) or not exp:
                errors.append(f"Concept '{cid}' quiz missing 'explanation'")

    # Read other files for validation
    current_file_path = os.environ.get("CURRENT_SEED_FILE", "")
    all_file_concepts = {}
    import glob
    for path in glob.glob("content/*.json"):
        if path.endswith(".example.json"):
            continue
        try:
            with open(path, "r", encoding="utf-8") as f:
                file_data = json.load(f)
                for oc in file_data.get("concepts", []):
                    oc_id = oc.get("id")
                    if oc_id:
                        all_file_concepts[oc_id] = (oc, path)
        except Exception:
            pass

    # Reject a concept id that already exists in another content file with different content
    for c in concepts:
        cid = c.get("id")
        if cid in all_file_concepts:
            existing_c, existing_path = all_file_concepts[cid]
            if existing_path != current_file_path and existing_path != "":
                if json.dumps(c, sort_keys=True) != json.dumps(existing_c, sort_keys=True):
                    errors.append(f"Concept '{cid}' already exists in another content file with different content.")

    defined_slugs.update(all_file_concepts.keys())

    # Second pass: check related dependencies
    for c in concepts:
        cid = c.get("id")
        for r in c.get("related", []):
            if r not in defined_slugs:
                if commit and db is not None:
                    try:
                        doc = db.collection(f"concepts_{field}").document(r).get()
                        if not doc.exists:
                            errors.append(f"Concept '{cid}' relates to undefined slug '{r}'")
                    except Exception as e:
                        errors.append(f"Failed to check Firestore for slug '{r}': {e}")
                else:
                    if not commit:
                        warnings.append(f"Note: Firestore was not checked for missing related concepts (dry-run). Slug '{r}' not found locally.")
                    else:
                        errors.append(f"Concept '{cid}' relates to undefined slug '{r}'")

    used_concept_ids = set()
    seen_dates = set()

    for i, ds in enumerate(daily_sets):
        if not isinstance(ds, dict):
            errors.append(f"Daily set at index {i} is not an object")
            continue

        date_str = ds.get("date")
        if not isinstance(date_str, str):
            errors.append(f"Daily set at index {i} missing/invalid 'date'")
        else:
            try:
                datetime.strptime(date_str, "%Y-%m-%d")
                if date_str in seen_dates:
                    errors.append(f"Duplicate date in daily sets: {date_str}")
                seen_dates.add(date_str)
            except ValueError:
                errors.append(f"Daily set date '{date_str}' is invalid format")

        if not isinstance(ds.get("theme"), str) or not ds.get("theme"):
            errors.append(f"Daily set '{date_str}' missing/invalid 'theme'")

        cids = ds.get("concept_ids")
        if not isinstance(cids, list) or len(cids) != 3 or len(set(cids)) != 3:
            errors.append(f"Daily set '{date_str}' must have exactly 3 distinct concept_ids")
        else:
            for cid in cids:
                if cid not in defined_slugs:
                    errors.append(f"Daily set '{date_str}' references undefined concept '{cid}'")
                used_concept_ids.add(cid)

    unused = defined_slugs - used_concept_ids
    for u in unused:
        warnings.append(f"Concept '{u}' is not used in any daily set")

    return errors, warnings

def main():
    parser = argparse.ArgumentParser(description='Seed concepts to Firestore.')
    parser.add_argument('file', help='Path to the content JSON file')
    parser.add_argument('--commit', action='store_true', help='Perform the writes to Firestore')
    parser.add_argument('--allow-review', action='store_true', help='Allow concepts with needs_review: true')
    args = parser.parse_args()

    with open(args.file, 'r', encoding='utf-8') as f:
        try:
            data = json.load(f)
        except json.JSONDecodeError as e:
            print(f"ERROR: Invalid JSON file: {e}")
            sys.exit(1)

    os.environ["CURRENT_SEED_FILE"] = os.path.abspath(args.file)
    field = data.get("field", "software_engineering")
    db = None
    
    if args.commit:
        print("\nConnecting to Firebase for validation...")
        os.environ["FIRESTORE_PREFER_REST"] = "true"
        import firebase_admin
        from firebase_admin import credentials, firestore
        if not firebase_admin._apps:
            cred = credentials.Certificate("serviceAccountKey.json")
            app = firebase_admin.initialize_app(cred)
            print(f"Project ID: {app.project_id}")
        db = firestore.client()

    errors, warnings = validate_payload(data, allow_review=args.allow_review, commit=args.commit, db=db)

    for w in warnings:
        print(f"WARNING: {w}")
    
    for e in errors:
        print(f"ERROR: {e}")

    if errors:
        print("\nValidation failed with errors. Aborting.")
        sys.exit(1)

    print("\nValidation passed.")
    
    if not args.commit:
        print("\n--- DRY RUN (no Firestore writes, no credentials read) ---")
        for c in data["concepts"]:
            print(f"  concepts_{field}/{c['id']}")
        for ds in data["daily_sets"]:
            print(f"  daily_sets_{field}/{ds['date']}")
        print("--- DRY RUN COMPLETE ---")
        return

    for c in data["concepts"]:
        c_id = c['id']
        db.collection(f"concepts_{field}").document(c_id).set(c)
        print(f"Wrote concepts_{field}/{c_id}")

    for ds in data["daily_sets"]:
        ds_date = ds['date']
        ds['field'] = field
        db.collection(f"daily_sets_{field}").document(ds_date).set(ds)
        print(f"Wrote daily_sets_{field}/{ds_date}")

    print("Seeding complete!")

if __name__ == '__main__':
    main()
