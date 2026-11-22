import pytest
from seed_concepts import validate_payload

def get_valid_payload():
    return {
        "field": "software_engineering",
        "concepts": [
            {
                "id": "concept-a",
                "term": "Concept A",
                "category": "cat",
                "level": "beginner",
                "definition": "This is a valid definition. It has exactly two sentences.",
                "summary": "A short line about concept A.",
                "analogy": "A short analogy.",
                "real_world_example": "A real world example.",
                "confused_with": None,
                "related": ["concept-b"],
                "needs_review": False,
                "quiz": {
                    "question": "Question?",
                    "options": ["Opt1", "Opt2", "Opt3", "Opt4"],
                    "answer_index": 0,
                    "explanation": "Explanation here."
                }
            },
            {
                "id": "concept-b",
                "term": "Concept B",
                "category": "cat",
                "level": "intermediate",
                "definition": "Another valid definition. Also two sentences.",
                "summary": "A short line about concept B.",
                "analogy": None,
                "real_world_example": "Another example.",
                "confused_with": "concept-a",
                "related": ["concept-a"],
                "needs_review": False,
                "quiz": {
                    "question": "Question 2?",
                    "options": ["A", "B", "C", "D"],
                    "answer_index": 3,
                    "explanation": "Explanation 2."
                }
            },
            {
                "id": "concept-c",
                "term": "Concept C",
                "category": "cat",
                "level": "advanced",
                "definition": "Third definition. Two sentences again.",
                "summary": "A short line about concept C.",
                "analogy": "Another short analogy.",
                "real_world_example": "Example 3.",
                "confused_with": None,
                "related": [],
                "needs_review": False,
                "quiz": {
                    "question": "Question 3?",
                    "options": ["1", "2", "3", "4"],
                    "answer_index": 1,
                    "explanation": "Explanation 3."
                }
            }
        ],
        "daily_sets": [
            {
                "date": "2026-10-05",
                "theme": "Theme",
                "concept_ids": ["concept-a", "concept-b", "concept-c"]
            }
        ]
    }

def test_valid_payload():
    errors, warnings = validate_payload(get_valid_payload())
    assert not errors
    assert not warnings

def test_missing_required_field():
    payload = get_valid_payload()
    del payload['field']
    errors, _ = validate_payload(payload)
    assert any("Missing or invalid root 'field'" in e for e in errors)

def test_invalid_slug():
    payload = get_valid_payload()
    payload['concepts'][0]['id'] = "Invalid Slug!"
    errors, _ = validate_payload(payload)
    assert any("invalid or missing slug" in e for e in errors)

def test_duplicate_slug():
    payload = get_valid_payload()
    payload['concepts'][0]['id'] = "concept-b"
    errors, _ = validate_payload(payload)
    assert any("Duplicate concept slug" in e for e in errors)

def test_undefined_related_concept_dry_run():
    payload = get_valid_payload()
    payload['concepts'][0]['related'] = ["undefined-concept"]
    errors, warnings = validate_payload(payload, commit=False)
    # in dry run it's a warning
    assert not errors
    assert any("Firestore was not checked" in w for w in warnings)

def test_undefined_related_concept_commit_fails_db():
    payload = get_valid_payload()
    payload['concepts'][0]['related'] = ["undefined-concept"]
    
    class FakeDoc:
        @property
        def exists(self): return False
        
    class FakeDocRef:
        def get(self): return FakeDoc()
        
    class FakeColl:
        def document(self, slug): return FakeDocRef()
        
    class FakeDb:
        def collection(self, name): return FakeColl()
        
    errors, warnings = validate_payload(payload, commit=True, db=FakeDb())
    assert any("relates to undefined slug" in e for e in errors)

def test_duplicate_concept_different_content(tmp_path, monkeypatch):
    import json
    import glob
    import seed_concepts
    
    mock_file = tmp_path / "mock.json"
    mock_file.write_text(json.dumps({
        "concepts": [
            {"id": "concept-a", "term": "Old Term"}
        ]
    }))
    
    monkeypatch.setattr(glob, "glob", lambda p: [str(mock_file)])
    
    payload = get_valid_payload() # concept-a has term 'Concept A'
    errors, warnings = seed_concepts.validate_payload(payload)
    assert any("already exists in another content file with different content" in e for e in errors)

def test_invalid_quiz_options():
    payload = get_valid_payload()
    payload['concepts'][0]['quiz']['options'] = ["One", "Two"]
    errors, _ = validate_payload(payload)
    assert any("exactly 4 non-empty string options" in e for e in errors)

def test_daily_set_concept_ids_count():
    payload = get_valid_payload()
    payload['daily_sets'][0]['concept_ids'] = ["concept-a", "concept-b"]
    errors, _ = validate_payload(payload)
    assert any("exactly 3 distinct concept_ids" in e for e in errors)

def test_daily_set_undefined_concept():
    payload = get_valid_payload()
    payload['daily_sets'][0]['concept_ids'] = ["concept-a", "concept-b", "concept-z"]
    errors, _ = validate_payload(payload)
    assert any("references undefined concept 'concept-z'" in e for e in errors)

def test_invalid_date():
    payload = get_valid_payload()
    payload['daily_sets'][0]['date'] = "05-10-2026"
    errors, _ = validate_payload(payload)
    assert any("invalid format" in e for e in errors)

def test_needs_review_without_flag():
    payload = get_valid_payload()
    payload['concepts'][0]['needs_review'] = True
    errors, _ = validate_payload(payload)
    assert any("needs_review: true, but --allow-review not passed" in e for e in errors)

    # With flag
    errors_allowed, _ = validate_payload(payload, allow_review=True)
    assert not errors_allowed

def test_backticks_in_definition():
    payload = get_valid_payload()
    payload['concepts'][0]['definition'] = "This is a `code` snippet. Still two sentences."
    errors, _ = validate_payload(payload)
    assert any("contains backticks" in e for e in errors)

def test_warning_sentence_count():
    payload = get_valid_payload()
    payload['concepts'][0]['definition'] = "Only one sentence."
    errors, warnings = validate_payload(payload)
    assert not errors
    assert any("expected 2-4" in w for w in warnings)

def test_warning_first_word():
    payload = get_valid_payload()
    payload['concepts'][0]['term'] = "Term"
    payload['concepts'][0]['definition'] = "Term is a thing. It is good."
    errors, warnings = validate_payload(payload)
    assert not errors
    assert any("starts with the term" in w for w in warnings)

def test_warning_unused_concept():
    payload = get_valid_payload()
    payload['concepts'].append({
        "id": "concept-d",
        "term": "Concept D",
        "category": "cat",
        "level": "beginner",
        "definition": "Valid definition here. Just two sentences.",
        "summary": "A short line about the extra concept.",
        "analogy": None,
        "real_world_example": "Example",
        "confused_with": None,
        "related": [],
        "needs_review": False,
        "quiz": {
            "question": "Q?",
            "options": ["1", "2", "3", "4"],
            "answer_index": 0,
            "explanation": "Exp"
        }
    })
    errors, warnings = validate_payload(payload)
    assert not errors
    assert any("is not used in any daily set" in w for w in warnings)

def test_warning_options_length():
    payload = get_valid_payload()
    payload['concepts'][0]['quiz']['options'] = ["Short", "Short", "Short", "This is an extremely long option that will trigger the warning"]
    errors, warnings = validate_payload(payload)
    assert not errors
    assert any("very different lengths" in w for w in warnings)


def test_missing_summary():
    payload = get_valid_payload()
    del payload["concepts"][0]["summary"]
    errors, _ = validate_payload(payload)
    assert any("missing 'summary'" in e for e in errors)

def test_summary_too_long():
    payload = get_valid_payload()
    payload["concepts"][0]["summary"] = " ".join(["word"] * 16)
    errors, _ = validate_payload(payload)
    assert any("summary is over 15 words" in e for e in errors)

def test_summary_too_many_characters():
    payload = get_valid_payload()
    payload["concepts"][0]["summary"] = "Extraordinarily " * 7 + "long."
    errors, _ = validate_payload(payload)
    assert any("summary is over 110 characters" in e for e in errors)
