#!/usr/bin/python3

import json
import base64
import sys


def is_it_file(content):
    # Actually only lenght check, other will be added
    if len(content) > 200:
        return(False)
    else:
        return(True)


def is_base64_encoded(content):
    try:
        # Try to decode the data
        decoded_data = base64.b64decode(content, validate=True)
        # Check if the decoded data can be re-encoded to the same value
        return base64.b64encode(decoded_data).decode('utf-8') == content
    except Exception:
        return False


def convert_to_json(content):
    # Decode the base64 content
    decoded_content = base64.b64decode(content).decode('utf-8')
    
    # Parse the decoded content as JSON
    json_content = json.loads(decoded_content)

    # Print the formatted JSON content
    #print(json.dumps(json_content, indent=4))

    return(json_content)    


def load_base64_file_as_json(content):
    with open(content, 'r') as file:
        encoded_content = file.read()

    json_content = convert_to_json(encoded_content)

    return(json_content)


def main(content):
    # admin_prefix = "admin"
    #content = sys.argv[1]
    msg_failure = {"result": "failure", "message": "Something is going wrong."}
    msg_success = {"result": "success", "message": "All is ok, publishing."}

    # Check if paramater is filepath or content?
    # if is_it_file(content):
    #     #print("Je to soubor.")
    #     data = load_base64_file_as_json(content)
    # else:
    #     #print("Neni to soubor.")
    #     data = convert_to_json(content)

    # Check if paramater is filepath or content?
    if is_base64_encoded(content):
        #print("Neni to soubor.")
        data = convert_to_json(content)
    else:
        #print("Je to soubor.")
        data = load_base64_file_as_json(content)

    # Load Smart Task Custom's parameters
    session_name_prefix=data['custom-data']['session-name-prefix']
    admin_prefix=data['custom-data']['admin-name-prefix']
    #print(admin_prefix, session_name_prefix)

    # Check if user-name contains the admin_prefix
    user_name = data["session"]["user-name"]
    if admin_prefix in user_name:
        user_can_publish = True
    else:
        user_can_publish = False

    # Check if 'modified-objects' and 'deleted-objects' are empty arrays, 
    # any added object has a type different from 'application-site' => define as a function?
    modified_objects_empty = len(data['operations']['modified-objects']) == 0
    deleted_objects_empty = len(data['operations']['deleted-objects']) == 0
    different_type_objects = [obj for obj in data['operations']['added-objects'] if obj['type'] != 'application-site']
    different_type_objects_empty = len(different_type_objects) == 0

    # Summary of testing
    summary = (f"added-objects are only application-site: {different_type_objects_empty},   " +
        f"modified-objects is empty: {modified_objects_empty},  " + 
        f"deleted-objects is empty: {deleted_objects_empty},    " + 
        f"user-name has priviledge do publish: {user_can_publish}   "
    )

    # Print result to SmartConsole's Smart Tasks
    if modified_objects_empty and deleted_objects_empty and different_type_objects_empty and user_can_publish:
        message = msg_success
    else:
        msg_failure['message'] = "Check Fails: {}".format(summary)
        message = msg_failure

    json.dump(message, sys.stdout)



if __name__ == '__main__':
    main(sys.argv[1])