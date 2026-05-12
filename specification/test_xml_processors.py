#!/usr/bin/python

from convert_xml import (get_random_hex_string, get_char_total_field_size,
                         process_char, process_service_char, process_service,
                         process_role, process_profile, add_dummy_data)


def test_hex_string():
    hex_string = get_random_hex_string(128)
    acceptable_chars = set(['0', '1', '2', '3', '4', '5', '6', '7', '8', '9',
                            'A', 'B', 'C', 'D', 'E', 'F'])
    chars = set()
    for char in hex_string:
        chars.add(char)
    non_hex_chars = chars.difference(acceptable_chars)
    assert len(non_hex_chars) == 0


def test_process_char():
    char_xml = '''
    <Characteristic name="Test Char Name" uuid="BEEF">
        <Field><Format>uint16</Format></Field>
        <Field><Format>nibble</Format></Field>
        <Field><Format>float</Format></Field>
        <Field><Format>sint24</Format></Field>
    </Characteristic>'''
    char = process_char(char_xml)
    assert char['name'] == 'Test Char Name'
    assert char['uuid'] == 'BEEF'
    assert char['field_size'] == 76


def test_process_service():
    service_xml = '''
    <Service name="Test Service Name" uuid="CAFE">
        <Characteristics>
            <Characteristic name="Char Alpha" type="org.test.char.alpha">
                <Properties>
                    <Read>Mandatory</Read>
                    <Write>Excluded</Write>
                    <Notify>Excluded</Notify>
                </Properties>
            </Characteristic>
            <Characteristic name="Char Bravo" type="org.test.char.bravo">
                <Properties>
                    <Read>Excluded</Read>
                    <Write>Mandatory</Write>
                    <Notify>Excluded</Notify>
                </Properties>
            </Characteristic>
            <Characteristic name="Char Charlie" type="org.test.char.charlie">
                <Properties>
                    <Read>Excluded</Read>
                    <Write>Excluded</Write>
                    <Notify>Mandatory</Notify>
                </Properties>
            </Characteristic>
        </Characteristics>
    </Service>'''
    service = process_service(service_xml)
    assert service['name'] == 'Test Service Name'
    assert service['uuid'] == 'CAFE'
    service_chars = service['chars']
    assert len(service_chars) == 3
    for char in service_chars:
        print char
        if char['type'] == 'org.test.char.alpha':
            assert char['props'] == ['read']
        elif char['type'] == 'org.test.char.bravo':
            assert char['props'] == ['write']
        elif char['type'] == 'org.test.char.charlie':
            assert char['props'] == ['notify']


def test_process_profile():
    profile_xml = '''
    <Profile name="Test Profile">
        <Role name="Test Service Role">
            <Service type="org.test.service.service"></Service>
        </Role>
        <Role name="Test Client Role">
            <Client type="org.test.service.client"></Service>
        </Role>
    </Profile>
    '''
    profile = process_profile(profile_xml)
    assert profile['name'] == 'Test Profile'
    roles = profile['roles']
    assert len(roles) == 2
    for role in roles:
        if role['name'] == 'Test Service Role':
            assert role['is_client'] is False
            assert role['is_service'] is True
            assert role['service_service_types'] == ['org.test.service.service']
        elif role['name'] == 'Test Client Role':
            assert role['is_client'] is True
            assert role['is_service'] is False
            assert role['client_service_types'] == ['org.test.service.client']
