# Create a user sign up page

Create a page where users can sign up
  route to add user users.yml
  validate
    username
      not empty
      not taken
    password
      at least 8 chars

## Test
test_sign_up_page
  get /signup
  assert
    200
    input
    button




test_sign_user_successfully
  post /create_user, {user, pw} -> correct
  assert
    302
    message in session
    user in session
    




test_sign_up_with_empty_or_taken_name
  post /create_user, empty user
  assert
    message in body
    422
    nil user
    

  post /create_user, taken user (admin)
  assert
    message in body
    422
    nil user





test_sign_up_with_invalid_password
  post /create_user,short password
  assert
    message in body
    422
    nil user


## HTML
  new sign up page

  like sign page

## Ruby
post create users

validate username
validate password

store username and hashed password in users

send message and redirect to index




