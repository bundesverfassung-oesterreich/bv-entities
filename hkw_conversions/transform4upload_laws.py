# creates csv from hkw-exist-db dumps. I used this create a baserow-table: https://baserow.acdh-dev.oeaw.ac.at/database/421/table/2558

import lxml.etree as et
from acdh_tei_pyutils.tei import TeiReader
temp_file_path = "./index.temp"
laws_filepath = "Gesetze_wip.xml"
csv_path = "laws.csv"
headings = [
    "register",
    "title_short",
    "title_short_original",
    "title_short_original_alt",
    "pubPlace",
    "expanded"
]

def clear_false_ns():
    import fileinput
    text_to_search = 'xml:id="xml:'
    with open(temp_file_path, 'w' ) as tempFile:
        for line in fileinput.input(laws_filepath):
            tempFile.write(
                line.replace(text_to_search, 'xml:id="')
            )


def get_row(el, row, namespaces):
    title_short = el.xpath("./tei:title[@type='short' and not(@subtype)]", namespaces=namespaces)
    row["title_short"] = title_short[0].text if title_short else ""
    register = el.xpath("./tei:title[@type='reg']", namespaces=namespaces)
    row["register"] = register[0].text if register else ""
    title_short_original = el.xpath("./tei:title[@type='short' and @subtype='original']", namespaces=namespaces)
    row["title_short_original"] = title_short_original[0].text if title_short_original else ""
    title_short_original_alt = el.xpath("./tei:title[@type='short' and @subtype='alt']", namespaces=namespaces)
    row["title_short_original_alt"] = title_short_original_alt[0].text if title_short_original_alt else ""
    pubPlace = el.xpath("./tei:pubPlace", namespaces=namespaces)
    row["pubPlace"] = pubPlace[0].text if pubPlace else ""
    expanded = el.xpath("./tei:bibl/tei:title/text()", namespaces=namespaces)
    row["expanded"] = "; ".join(expanded)
    return row


if __name__=="__main__":
    import csv
    delete_later = False
    try:
        law_doc = TeiReader(laws_filepath)
    except et.XMLSyntaxError:
        clear_false_ns()
        law_doc = TeiReader(temp_file_path)
        delete_later = True
    laws = [
        dict(
            [(h, h) for h in headings]
        )
    ]
    law_elements = law_doc.any_xpath("//tei:listBibl/tei:bibl")
    print(f"{len(law_elements)} elemente gefunden.")
    for law in law_elements:
        row = dict.fromkeys(headings)
        laws.append(
            get_row(law, row, law_doc.nsmap)
        )
    print(f"{len(laws)-1} gesetze gefunden")
    with open(csv_path, "w") as outfile:
        writer = csv.DictWriter(outfile, fieldnames=headings)
        writer.writerows(laws)