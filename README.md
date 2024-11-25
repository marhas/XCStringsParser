# XCStringsParser

Converts XCStrings file to CSV and back

I use this tool to export my localizations for translation by people that aren't comfortable using Xcode.
Mabye it could be useful for your project too?


## Usage

### Exporting localizations
This will export the selected languages together with the translation keys and the comments (to help the translator with context)
> swift run XCStringsParser [options] <source .xcstrings file> <destination .csv file>
>  options:
>    -d delimiter. Default is ;
>    -l languages. Comma separated list of language codes to export

For example, to use a pipe character as the delimiter for the CVS file and export English and Spanish strings:
> swift run XCStringsParser -d "|" -l en,es


### Imorting localizations
The tranlsator would manually edit the CSV and either add a column for the language being translated to, or update the existing translations. This file can then be imported back into your xcstrings file.
This will import the selected languages from a previously exported, translated CSV file. Note that comments will not be imported, the idea being that the comments are there to help the translator and we do not expect the translator to edit the comments.
> swift run XCStringsParser [options] <.csv file to import> <.xcstrings file to import to>
>  options:
>    -d delimiter. Default is ;
>    -l languages. Comma separated list of language codes to import

For example, to import all languages from the CSV to your xcstrings file:
> swift run XCStringsParser myTranslations.csv /my/project/Localizable.xcstrings

To import only Spanish and English translations, and use a pipe character as the CSV delimiter:
> swift run -d "|" -l es,en XCStringsParser myTranslations.csv /my/project/Localizable.xcstrings