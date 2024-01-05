# koha-plugin-updatemarcfield

## UpdateMarcFields koha-plugin

This plugin provides a way to append data fields in Koha MARC records optionaly based on a regex criteria. It also provides the ability to delete data fields based on a regex expression.

## Usage
The plugin expects a CSV file with the following format as input.

biblionumber,data_field,ind1,ind2,criteria_subfield,criteria,sub-field codes[,..]

The criteria_subfield and criteria fields may both be omitted OR individual
records may have these fields empty. If so, then the data_field will be
appended. If they exist and the criteria field matches the value of the
criteria_subfield in the record then all the existing matching subfields will
be deleted first. The criteria is a PERL Regex. As many sub-field codes as desired may be added.

Any other empty fields will not be included in added records. This can be used
to delete sub-fields by having a criteria and criteria_field with all other
sub-field codes empty.

CSV Header Description:
biblionumber - Koha biblio number, required
data_field - MARC data field number, required
ind1 - MARC ind1 field, defaults to blank if not present
ind2 - MARC ind2 field, defaults to blank if not present
criteria_subfield - MARC subfield tag value to check against criteria, may be omitted
criteria - MARC subfield criteria, a PERL Regex
"sub-field-code" - MARC subfield code value to add, may be repeated for different sub-field values

## Example file

biblionumber,data_field,ind1,ind2,criteria_subfield,criteria,d,f,q,u,y
2058,856,4,0,,^(http\:|https\:)\/\/sacfsl\/,/Library/titles/72,383272U.pdf,application/pdf,http://sacfsl-storage//Library/titles/27/382272U.pdf,Test sample U
2058,856,4,0,u,,/Library/titles/27,383272T.pdf,application/pdf,http://sacfsl-storage//Library/titles/27/382272T.pdf,Test sample T
2445,856,4,0,u,^(http\:|https\:)\/\/sacfsl-storage\/,/Library/titles/07,510207_02.pdf,application/pdf,http://sacfsl-storage//Library/titles/07/510207_02.pdf,v.2
2445,856,4,0,u,^(http\:|https\:)\/\/sacfsl-storage\/,/Library/titles/07,510207_04.pdf,application/pdf,http://sacfsl-storage//Library/titles/07/510207_04.pdf,v.4
1063,856,4,0,,^(http\:|https\:)\/\/sacfsl-storage\/,/Library/titles/63,168963A.pdf,application/pdf,http://sacfsl-storage//Library/titles/07/168963A.pdf,v.4
1968,856,,,u,^(http\:|https\:)\/\/sacfsl-storage\/,,,,

## Quick Installation Steps

Download the package file UpdateMarcField_xx.kpz

Login to Koha Admin and go to the plugin screen

Upload Plugin
