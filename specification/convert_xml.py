#!/usr/bin/python

import yaml
import json
import random
import string
from os import listdir
from os.path import isfile, join
from bs4 import BeautifulSoup

LOC_CONFIG_FILE = 'config.yml'

# load configuration
with open(LOC_CONFIG_FILE, 'r') as f:
    config = yaml.load(f, Loader=yaml.UnsafeLoader)

# load field formats
with open(config['loc_formats'], 'r') as f:
    formats = yaml.load(f, Loader=yaml.UnsafeLoader)

# folders containing XML files
folder_profiles = config['loc_profiles']
folder_services = config['loc_services']
folder_chars = config['loc_characteristics']

# filenames in each folder (e.g. org.bluetooth.[...].heart_rate.xml)
# Filter all folders and non-.xml files
profile_files = list(f for f in listdir(folder_profiles)
                     if (isfile(join(folder_profiles, f))
                         and f.lower().endswith('.xml')))
service_files = list(f for f in listdir(folder_services)
                     if (isfile(join(folder_services, f))
                         and f.lower().endswith('.xml')))
char_files = list(f for f in listdir(folder_chars)
                  if (isfile(join(folder_chars, f))
                      and f.lower().endswith('.xml')))

num_profiles = len(profile_files)
num_services = len(service_files)
num_chars = len(char_files)

# names of each profile, service, or characteristic (no .xml)
# (e.g. org.bluetooth.[...].heart_rate)
# also known as "types" I think?
profile_names = list(f.split('.xml')[0] for f in profile_files)
service_names = list(f.split('.xml')[0] for f in service_files)
char_names = list(f.split('.xml')[0] for f in char_files)

# file locations for each file in each folder
# (e.g. Profiles/org.bluetooth.[...].heart_rate.xml)
profile_locs = list(join(folder_profiles, f) for f in profile_files)
service_locs = list(join(folder_services, f) for f in service_files)
char_locs = list(join(folder_chars, f) for f in char_files)


def get_random_hex_string(length):
    '''Return a string of random uppercase hex digits of the given length.'''
    return ''.join(random.choice('ABCDEF' + string.digits) for x in range(length))


def get_char_total_field_size(char_xml):
    '''
    Get the total size of all fields in a characteristic.
    Return -1 if size is indeterminate (variable field sizes, arrays, etc).
    '''
    char_formats = char_xml.find_all('format')
    all_formats = list(format.text.lower() for format in char_formats)
    if len(all_formats) == 0:
        return -1  # no <format> tags found in xml
    all_format_sizes = []
    for format in all_formats:
        try:
            format_size = formats[format]
        except KeyError:
            return -1  # format not found in format size list
        all_format_sizes.append(format_size)
    return sum(all_format_sizes)


def process_char(raw_char_xml):
    '''Given the XML of a characteristic, return its data dict representation.'''
    char_data = {}
    char_xml = BeautifulSoup(raw_char_xml)
    char_tag = char_xml.find('characteristic')
    char_name = char_tag['name']
    if config['debug']:
        print('Characteristic: %s' % char_name)
    char_data['name'] = char_name
    char_uuid = char_tag['uuid']
    char_data['uuid'] = char_uuid
    char_field_size = get_char_total_field_size(char_xml)
    char_data['field_size'] = char_field_size
    return char_data


def process_service_char(service_char_soup):
    '''Given the XMLsoup of a characteristic listing inside a service, return the data dict representation.'''
    char_data = {}
    if config['debug']:
        print('    Characteristic: %s' % char_name)
    char_type = service_char_soup['type']
    char_data['type'] = char_type
    char_props = []
    # The list of properties pulled from the XML file has a bunch
    # of blanks (\n). Filter those out, and filter the list so that
    # only properties that are labeled 'Mandatory' show up.
    char_props_mandatory = list(prop.name for prop in service_char_soup.find('properties').children
                                if (prop != (u'\n') and prop.text == 'Mandatory'))
    for prop_name in char_props_mandatory:
        if config['debug']:
            print('        Property: %s' % prop_name)
        char_props.append(prop_name)
    char_data['props'] = char_props
    return char_data


def process_service(raw_service_xml):
    '''Given the XML of a service, return its data dict representation and process inline characteristics.'''
    service_data = {}
    service_xml = BeautifulSoup(raw_service_xml)
    service_tag = service_xml.find('service')
    service_name = service_tag['name']
    if config['debug']:
        print('Service: %s' % service_name)
    service_data['name'] = service_name
    service_uuid = service_tag['uuid']
    service_data['uuid'] = service_uuid
    service_chars = service_xml.find_all('characteristic')
    chars = []
    for char in service_chars:
        char_data = process_service_char(char)
        chars.append(char_data)
    service_data['chars'] = chars
    return service_data


def process_role(role_xml):
    '''Given the XML of a role, return its data dict representation.'''
    role_data = {}
    role_name = role_xml['name']
    role_data['name'] = role_name
    role_is_service = False
    role_is_client = False
    role_service_services = role_xml.find_all('service')
    role_client_services = role_xml.find_all('client')
    if len(role_service_services) > 0:
        role_is_service = True
        role_service_service_types = list(service['type'] for service
                                          in role_service_services)
        role_data['service_service_types'] = role_service_service_types
    if len(role_client_services) > 0:
        role_is_client = True
        role_client_service_types = list(service['type'] for service
                                         in role_client_services)
        role_data['client_service_types'] = role_client_service_types
    role_data['is_service'] = role_is_service
    role_data['is_client'] = role_is_client
    return role_data


def process_profile(raw_profile_xml):
    '''Given the XML of a profile, return its data dict representation.'''
    profile_data = {}
    profile_xml = BeautifulSoup(raw_profile_xml)
    profile_name = profile_xml.find('profile')['name']
    if config['debug']:
        print('Profile: %s' % profile_name)
    profile_data['name'] = profile_name
    roles = profile_xml.find_all('role')
    roles_data = []
    for role_xml in roles:
        role_data = process_role(role_xml)
        roles_data.append(role_data)
    profile_data['roles'] = roles_data
    return profile_data


def add_dummy_data(char_field_size, char_props, props_out):
    '''
    Given a characteristic field size char_field_size, generate dummy data
    and add it in-place to data dicts char_props and props_out.
    '''
    num_hex_chars = char_field_size * 2
    if 'read' in char_props:
        # read_string = random 8-char hex string
        if char_field_size == -1:
            read_string = 'UNKNOWN_FIELD_SIZE'
        else:
            read_string = get_random_hex_string(num_hex_chars)
        props_out['read_string'] = read_string
    if 'notify' in char_props:
        # notify_values = ["0x[random 4-char hex string]" * 3 to 8]
        notify_values = []
        num_notify_values = random.randint(3, 8)
        for i in range(num_notify_values):
            if char_field_size == -1:
                notify_values.append('UNKNOWN_FIELD_SIZE')
                props_out['read_is_ascii'] = True
            else:
                notify_values.append(get_random_hex_string(num_hex_chars))
        props_out['notify_values'] = notify_values
        props_out['notify_delay'] = 1
    props_out['permission_read'] = True

# main function
if __name__ == "__main__":

    # process characteristics, then services, then profiles.
    # do it in this order so that dicts can be made from lowest to highest
    # level data, limiting the number of reads from disk to a minimum
    chars = {}
    for char_num in range(num_chars):
        char_name = char_names[char_num]
        char_loc = char_locs[char_num]
        with open(char_loc, 'r') as f:
            char_xml = f.read()
        chars[char_name] = process_char(char_xml)

    services = {}
    for service_num in range(num_services):
        service_name = service_names[service_num]
        service_loc = service_locs[service_num]
        with open(service_loc, 'r') as f:
            service_xml = f.read()
        services[service_name] = process_service(service_xml)

    profiles = {}
    for profile_num in range(num_profiles):
        profile_name = profile_names[profile_num]
        profile_loc = profile_locs[profile_num]
        with open(profile_loc, 'r') as f:
            profile_xml = f.read()
        profiles[profile_name] = process_profile(profile_xml)

    # Perform final processing into output JSON format
    output = []  # list of profiles
    for profile_type, profile_data in profiles.items():
        profile_out = {}
        profile_out['name'] = profile_data['name']
        for role in profile_data['roles']:
            all_service_types = set()
            if role['is_service']:
                all_service_types |= set(role['service_service_types'])
            if role['is_client']:
                all_service_types |= set(role['client_service_types'])
            all_service_types = list(all_service_types)
            for service_type in all_service_types:
                service = services[service_type]
                service_uuid = service['uuid']
                service_data = {}
                service_chars = service['chars']
                for service_char in service_chars:
                    char_type = service_char['type']
                    char_props = service_char['props']
                    char = chars[char_type]
                    char_uuid = char['uuid']
                    props_out = {}
                    # ADD IN DUMMY DATA HERE.
                    # Pay attention and take this out when this script goes live
                    add_dummy_data(char['field_size'], char_props, props_out)
                    # DUMMY DATA SECTION IS DONE, YO
                    for prop_name in char_props:
                        props_out[prop_name] = True
                    service_data[char_uuid] = props_out
                profile_out[service_uuid] = service_data
        output.append(profile_out)

    # dump json to loc_json_out from config.yml
    with open(config['loc_json_out'], 'w') as f:
        if config['pretty_json']:
            json.dump(output, f, indent=4)
        else:
            json.dump(output, f)

    print('JSON saved to %s.' % config['loc_json_out'])
