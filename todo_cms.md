# These are the todos for the development of the CMS system

## Editing Documents Content

When a user clicks the edit link, he is directed to a page where he can change
the content of the document

### Clicking Save Changes

The user comes back to index
flash message @FILENAME has been updated

### Ruby

take the value of param content
open the correct file to write

write content to file
close file


set session message
redirect /



### Test
create a new document - test.txt
fill with "original content"
POST /test.txt
set @content to "content updated"

assert status 302
follow 302

assert status 200
assert includes test.txt has been updated.

GET /test.txt
assert status 200
includes "content updated"

delete test.txt
