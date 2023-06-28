import lxml.etree as et
from acdh_tei_pyutils.tei import TeiReader
temp_file_path = "./index.temp"
person_filepath = "Personen.xml"
temp_file_path = "index.temp"
jsonoutpath = "index.json"
headings = [
    "hkw_idnos",
    "gnd",
    "register_name",
    "alt_name",
    "birth_name",
    "birth",
    "death",
    "biography",
]

def clear_false_ns():
    import fileinput
    text_to_search = 'xml:id="xml:'
    with open(temp_file_path, 'w' ) as tempFile:
        for line in fileinput.input(person_filepath):
            tempFile.write(
                line.replace(text_to_search, 'xml:id="')
            )


def get_row(person, row):
    hkw_id = person.get(f"{{{person_doc.ns_xml['xml']}}}id")
    if row["hkw_idnos"] != "":
        row["hkw_idnos"] += f", {hkw_id}"
    else:
        row["hkw_idnos"] = hkw_id
    for tag in person:
        name = tag.xpath("local-name()")
        value = ""
        if name == "idno":
            name = "gnd"
            value = tag.text
            # 2 types exist (gnd, uri) both contain gnd link
        if name == "persName":
            if not "type" in tag.attrib or tag.attrib["type"] == "reg":
                name = "register_name"
            elif tag.attrib["type"] == "alt":
                if "subtype" in name:
                    name = "birth_name"
                else:
                    name = "alt_name"
            value = ""
            first = ""
            last = ""
            for subtag in tag:
                if subtag.xpath("local-name()") == "name":
                    value = subtag.text
                else:
                    if subtag.xpath("local-name()") == "surname":
                        last = subtag.text
                    elif subtag.xpath("local-name()") == "forename":
                        first = subtag.text
            if value and (first or last):
                print(value, first, last)
                raise ValueError
            elif not value:
                value = f"{last}, {first}"
        if name == "birth" and tag.text and tag.text.strip():
            value = tag.text
        if name == "death" and tag.text and tag.text.strip():
            value = tag.text
        if name == "linkGrp":
            # 2 types: note, page; both pointing to hkw
            name = ""
        if name == "note":
            #biography
            #printed
            #status
            #interna
            #type_ghl_csb_nxb
            #type_qjn_dzb_nxb
            #comment
            if tag.get("type") == "biography":
                name = "biography"
                value = tag.text
            elif tag.get("type") == "printed":
                name = ""
            elif tag.get("type") == "status":
                name = ""
            elif tag.get("type") == "interna":
                name = ""
            elif tag.get("type") == "type_ghl_csb_nxb":
                name = "biography"
                value = tag.text
            elif tag.get("type") == "type_qjn_dzb_nxb":
                name = "biography"
                value = tag.text
            elif tag.get("type") == "comment":
                name = ""
        if name == "ab":
            if tag.get("type") == "current":
                row = get_row(person=tag, row=row)
                name = ""
            else:
                name = ""
        if name != "":
            if row[name] != "":
                input(f"{name} exisiter mehrfach!")
                #raise ValueError
            else:
                row[name] = value
    return row

if __name__=="__main__":
    import json
    delete_later = False
    try:
        person_doc = TeiReader(person_filepath)
    except et.XMLSyntaxError:
        clear_false_ns()
        person_doc = TeiReader(temp_file_path)
        delete_later = True
    with open(jsonoutpath, "w") as outfile:
        persons = []
        for person in person_doc.any_xpath(".//tei:person"):
            dummy = dict((key, "") for key in headings)
            person = get_row(person, dummy)
            persons.append(person)
        json.dump(persons, outfile)
    if delete_later:
        import os
        os.remove(temp_file_path)