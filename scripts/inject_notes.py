import xml.etree.ElementTree as ET
import os
import sys

def main():
    if not os.path.exists('appcast.xml'):
        sys.exit(0)
    if not os.path.exists('release_notes.md'):
        sys.exit(0)

    with open('release_notes.md', 'r') as f:
        notes = f.read()

    # Pre-wrap allows GitHub markdown to preserve its look
    html_notes = '<html><body><h2>Release Notes</h2><pre style="white-space: pre-wrap;">' + notes + '</pre></body></html>'
    cdata = '<description><![CDATA[' + html_notes + ']]></description>'

    with open("appcast.xml", "r") as f:
        appcast = f.read()

    if "<description>" not in appcast:
        with open("appcast.xml", "w") as f:
            f.write(appcast.replace("<item>", "<item>\n            " + cdata))

if __name__ == "__main__":
    main()
