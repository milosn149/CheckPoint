#!/usr/bin/python3

import json
import base64
import sys

user_prefix = "admin"
msg_failure = {"result": "failure", "message": "Something is going wrong."}
msg_success = {"result": "success", "message": "All is ok, publishing."}

def load_base64_file_as_json(file_path):
    with open(file_path, 'r') as file:
        encoded_content = file.read()
    
    # Decode the base64 content
    decoded_content = base64.b64decode(encoded_content).decode('utf-8')
    
    # Parse the decoded content as JSON
    json_content = json.loads(decoded_content)
    
    # Print the formatted JSON content
    #print(json.dumps(json_content, indent=4))

    return(json_content)

def check_summary ():
    # Checks results
    summary = (f"added-objects are only application-site: {different_type_objects_empty}, " + 
        f"modified-objects is empty: {modified_objects_empty}, " + 
        f"deleted-objects is empty: {deleted_objects_empty}, " + 
        f"user-name has priviledge do publish: {user_can_publish}"
    )

    # Only for detailed testing
    # print(f"added-objects are only application-site: {different_type_objects_empty}")
    # print(f"modified-objects is empty: {modified_objects_empty}")
    # print(f"deleted-objects is empty: {deleted_objects_empty}")
    # print(f"user-name has priviledge do publish: {user_can_publish}")
    
    # Only for detailed testing
    #if different_type_objects:
    #    print(f"Objects with different types: {len(different_type_objects)}")
    #    #for obj in different_type_objects:
    #    #    print(obj)
    #else:
    #    print("No objects with different types than \"application-site\" found.")

    return(summary)


# main() ???
# Example usage
file_path = sys.argv[1]
data = load_base64_file_as_json(file_path)

# Check if 'modified-objects' and 'deleted-objects' are empty arrays
modified_objects_empty = len(data['operations']['modified-objects']) == 0
deleted_objects_empty = len(data['operations']['deleted-objects']) == 0

# Check if any added object has a type different from 'application-site' => define as a function?
different_type_objects = [obj for obj in data['operations']['added-objects'] if obj['type'] != 'application-site']
different_type_objects_empty = len(different_type_objects) == 0

# Check if user-name contains the user_prefix
user_name = data["session"]["user-name"]
if user_prefix in user_name:
    user_can_publish = True
else:
    user_can_publish = False

# Print result to SmartConsole's Smart Tasks
if modified_objects_empty and deleted_objects_empty and different_type_objects_empty and user_can_publish:
    message = msg_success
else:
    msg_failure['message'] = "Check Fails: {}".format(check_summary())
    message = msg_failure

json.dump(message, sys.stdout)



