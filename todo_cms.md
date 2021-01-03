# Delete a document

delete button next to document when open
delete docuement and show message $Filenmae was deleted.

## Show delete button
add button to index page
  action to /:filename/delete
  method post

add route to delete
  data_path + params filename -> join
  File.delete on path


## Test
Test that a delete button is on index page

Test deleting a document
  set up document
  call the delete route
  check that decument does not exist on index page
  check redirection
  check message 
