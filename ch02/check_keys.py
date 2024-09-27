import boto3
import datetime

MAX_AGE_DAYS = 7

iam = boto3.client("iam")

def get_key_age(access_key):
    create_date = access_key['CreateDate']
    current_date = datetime.datetime.now(tz=datetime.timezone.utc)

    age = current_date - create_date
    return age.days

def main():
    all_users = iam.list_users()["Users"]

    keys_for_rotation = []
    for user in all_users:
        user_name = user['UserName']
        key_response = iam.list_access_keys(UserName=user_name)

        print(f"User: {user_name}")
        for access_key in key_response["AccessKeyMetadata"]:
            key_id = access_key['AccessKeyId']
            age = get_key_age(access_key)

            print(f"- {key_id}: {age}")

            if age > MAX_AGE_DAYS:
                keys_for_rotation.append((user_name, key_id))
    
    print()
    print("Keys for rotation:")
    for user, key_id in keys_for_rotation:
        print(f"{key_id} from user {user}")
if __name__ == "__main__":
    main()