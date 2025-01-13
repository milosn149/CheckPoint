#!/usr/bin/python3
"""Check if the user is allowed to publish the changes.

The script is a SmartTask for Check Point Security Management server.
In case the admin name starts with the given prefix the script checks
if the user is allowed to publish the changes.

Parameters:
    - custom-data.admin-name-prefix
        The admin name prefix for the limited users.
"""

import json
import base64
import sys
import logging


MSG_FAILURE = {"result": "failure", "message": "Something went wrong."}
MSG_SUCCESS = {"result": "success", "message": "Everything is ok, publishing."}
ADMIN_NAME_PREFIX_PARAMETER = "admin-name-prefix"


def is_file(cli_argument):
    """Return True if the argument is a file path, False otherwise.

    Only argument length is checked.
    """
    return len(cli_argument) <= 200


def is_base64_encoded(string):
    """Return True if the string is base64 encoded, False otherwise."""
    try:
        decoded_data = base64.b64decode(string, validate=True)
        return base64.b64encode(decoded_data).decode('utf-8') == string
    except ValueError:
        return False


def get_json_data_from_base64(string):
    """Return JSON data from base64 encoded string."""
    decoded_content = base64.b64decode(string).decode('utf-8')
    json_content = json.loads(decoded_content)
    logging.debug(json.dumps(json_content, indent=4))

    return json_content


def get_json_data_from_base64_file(content):
    """Return JSON data from base64 encoded file."""
    with open(content, 'r') as file:
        encoded_content = file.read()

    json_content = get_json_data_from_base64(encoded_content)
    logging.debug(json.dumps(json_content, indent=4))

    return json_content


def dump_json_message(message):
    """Print JSON message to stdout."""
    json.dump(message, sys.stdout)
    print()


def dump_json_data_to_file(data, file_path):
    """Dump JSON data to file."""
    with open(file_path, 'w') as file:
        json.dump(data, file, indent=4)


def main(cli_argument):
    """Main function of the script."""
    logging.basicConfig(level=logging.WARNING)

    # Check if parameter is filepath or content?
    # if is_it_file(content):
    if is_base64_encoded(cli_argument):
        logging.debug("Argument is a base64 encoded string.")
        data = get_json_data_from_base64(cli_argument)
    else:
        logging.debug("Argument is a file path.")
        data = get_json_data_from_base64_file(cli_argument)

    if logging.getLogger().isEnabledFor(logging.DEBUG):
        dump_json_data_to_file(data, '/var/log/tmp/check_before_publish_data.json')

    # Load Smart Task Custom's parameters
    session_name_prefix = data['custom-data']['session-name-prefix']
    try:
        admin_name_prefix = data['custom-data'][ADMIN_NAME_PREFIX_PARAMETER]
    except KeyError as exception:
        raise KeyError(
            f"Custom data parameter '{ADMIN_NAME_PREFIX_PARAMETER}' is missing."
            ) from exception
    logging.debug("Session Name Prefix: %s", session_name_prefix)
    logging.debug("Admin Name Prefix: %s", admin_name_prefix)

    # Check if user-name starts with the admin_prefix
    user_name = data["session"]["user-name"]
    if user_name.startswith(admin_name_prefix):
        publishing_by_user_is_limited = True
    else:
        publishing_by_user_is_limited = False

    # Check if 'modified-objects' and 'deleted-objects' are empty arrays,
    # any added object has a type different from 'application-site' => define as a function?
    modified_objects_empty = len(data['operations']['modified-objects']) == 0
    deleted_objects_empty = len(data['operations']['deleted-objects']) == 0
    added_disallowed_objects = [
            obj for obj in data['operations']['added-objects']
            if obj['type'] != 'application-site']
    added_disallowed_objects_empty = not added_disallowed_objects

    # Summary of testing
    summary = (
        f"added-objects are only application-site: {added_disallowed_objects_empty},   "
        f"modified-objects is empty: {modified_objects_empty},   "
        f"deleted-objects is empty: {deleted_objects_empty},   "
        f"user-name has publishing limited: {publishing_by_user_is_limited}   "
    )

    # Print result to SmartConsole's Smart Tasks
    if (
            not publishing_by_user_is_limited or (
            modified_objects_empty and deleted_objects_empty
            and added_disallowed_objects_empty)
    ):
        message = MSG_SUCCESS.copy()
    else:
        message = MSG_FAILURE.copy()
        message['message'] = f"Check Fails: {summary}"

    dump_json_message(message)


if __name__ == '__main__':
    try:
        main(sys.argv[1])
    except Exception as exception:
        message = MSG_FAILURE.copy()
        message['message'] = (
            f"General Exception: {exception.__class__.__name__}: {exception}")
        dump_json_message(message)
        raise exception
