import os
os.environ["FIRESTORE_PREFER_REST"] = "true"

import json
import argparse
from datetime import datetime, timedelta

# ---------------------------------------------------------
# CONFIGURATION
# ---------------------------------------------------------
SERVICE_ACCOUNT_KEY_PATH = 'serviceAccountKey.json'

# Firestore Collections
CONTENT_COLLECTION = 'content_software_engineering'
QUIZ_COLLECTION = 'quizzes_software_engineering'
# ---------------------------------------------------------

def initialize_firebase():
    """Initialize Firebase Admin SDK."""
    import firebase_admin
    from firebase_admin import credentials
    from firebase_admin import firestore
    try:
        cred = credentials.Certificate(SERVICE_ACCOUNT_KEY_PATH)
        firebase_admin.initialize_app(cred)
        return firestore.client()
    except Exception as e:
        print(f"Failed to initialize Firebase: {e}")
        print("Make sure you have downloaded your 'serviceAccountKey.json' from the Firebase Console (Project Settings > Service Accounts) and placed it in the same directory.")
        exit(1)

def is_saturday(date_str):
    """Check if a given date string (YYYY-MM-DD) is a Saturday."""
    date_obj = datetime.strptime(date_str, '%Y-%m-%d')
    return date_obj.weekday() == 5  # Monday is 0, Saturday is 5

def get_week_start(date_str):
    """Given a Saturday date string, return the preceding Sunday date string."""
    date_obj = datetime.strptime(date_str, '%Y-%m-%d')
    sunday_obj = date_obj - timedelta(days=6)
    return sunday_obj.strftime('%Y-%m-%d')

def run_import(content_path, dry_run=False):
    db = None
    if not dry_run:
        db = initialize_firebase()

    print(f"Reading data from {content_path}...")
    with open(content_path, 'r', encoding='utf-8') as f:
        raw_data = json.load(f)

    weekly_questions = []

    if dry_run:
        print("\n--- DRY RUN (no Firestore writes, no credentials read) ---\n")
    else:
        print("\nStarting Import...")

    for day_data in raw_data:
        date_id = day_data.get('date_id')
        word = day_data.get('word')

        # 1. Extract Quiz Questions
        daily_questions = day_data.pop('quiz_questions', [])
        for q in daily_questions:
            q['source_word'] = word
            weekly_questions.append(q)

        if dry_run:
            print(f"  {CONTENT_COLLECTION}/{date_id}  ->  {word}")
        else:
            daily_ref = db.collection(CONTENT_COLLECTION).document(date_id)
            daily_ref.set(day_data)
            print(f"Uploaded Word of the Day: {word} ({date_id})")

        # 2. If it's Saturday, bundle the week's questions into a Weekly Quiz
        if is_saturday(date_id):
            week_start = get_week_start(date_id)

            quiz_data = {
                'week_start': week_start,
                'week_end': date_id,
                'questions': weekly_questions
            }

            if dry_run:
                print(f"  {QUIZ_COLLECTION}/{date_id}  ->  Weekly Quiz ({week_start} to {date_id}), {len(weekly_questions)} questions")
            else:
                quiz_ref = db.collection(QUIZ_COLLECTION).document(date_id)
                quiz_ref.set(quiz_data)
                print(f"Uploaded Weekly Quiz for week ending {date_id} ({len(weekly_questions)} questions)")

            weekly_questions = []

    if weekly_questions:
        if dry_run:
            print(f"\n  Warning: {len(weekly_questions)} leftover questions not bundled (no trailing Saturday)")

    if dry_run:
        print("\n--- DRY RUN COMPLETE ---")
    else:
        print("\nImport Complete!")

if __name__ == '__main__':
    parser = argparse.ArgumentParser(description='Import daily content and weekly quizzes to Firestore.')
    parser.add_argument('content_file', nargs='?', default='content_json.json',
                        help='Path to the content JSON file (default: content_json.json)')
    parser.add_argument('--dry-run', action='store_true',
                        help='Print what would be uploaded without writing to Firestore or reading credentials')
    args = parser.parse_args()

    run_import(args.content_file, dry_run=args.dry_run)
