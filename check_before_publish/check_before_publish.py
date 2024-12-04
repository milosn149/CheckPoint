#!/usr/bin/python3

import json
import base64
import sys

json_content = ""
user_prefix = ""

def load_and_print_base64_file_as_json(file_path):
    with open(file_path, 'r') as file:
        encoded_content = file.read()
    
    # Decode the base64 content
    decoded_content = base64.b64decode(encoded_content).decode('utf-8')
    
    # Parse the decoded content as JSON
    json_content = json.loads(decoded_content)
    
    # Print the formatted JSON content
    #print(json.dumps(json_content, indent=4))

    return(json_content)

# Example usage
#file_path = 'data.base64'
file_path = sys.argv[1]
data = load_and_print_base64_file_as_json(file_path)

# Check if 'modified-objects' and 'deleted-objects' are empty arrays
modified_objects_empty = len(data['operations']['modified-objects']) == 0
deleted_objects_empty = len(data['operations']['deleted-objects']) == 0

# Check if any added object has a type different from 'application-site' => define as a function?
different_type_objects = [obj for obj in data['operations']['added-objects'] if obj['type'] != 'application-site']
different_type_objects_empty = len(different_type_objects) == 0

# Checks results
print(f"added-objects are only application-site: {different_type_objects_empty}")
print(f"modified-objects is empty: {modified_objects_empty}")
print(f"deleted-objects is empty: {deleted_objects_empty}")

# Only for detailed testing
if different_type_objects:
    print(f"Objects with different types: {len(different_type_objects)}")
    #for obj in different_type_objects:
    #    print(obj)
else:
    print("No objects with different types than \"application-site\" found.")

# Print result to SmartConsole's Smart Tasks
if modified_objects_empty and deleted_objects_empty and different_type_objects_empty:
    print('All is ok, publishing.')


