Two days ago a new version of Ramaze was released. This version (2011.01) no longer has a 
large amount of form helpers like it used to,  they're all dropped in favor of the 
BlueForm helper. The reason they were dropped is that most of them pretty much did the 
same job although in a slightly different way. While I made these changes a while ago 
there hasn't been a release since the summer of '10 and since a few people seemed to have 
some problems understanding how this (improved) version of BlueForm works I figured it was 
a good idea to write a little article on it.

The biggest difference is that the BlueForm helper is a block rather than just a 
collection of methods that can be used individually, I also modified it to work a bit 
like the form_for() method that ships with Rails (and actually named it the same). Let's 
say we have the following basic controller:

```ruby
require 'ramaze'
require 'sequel'

class Main < Ramaze::Controller
  map '/'
  helper :blue_form

  def index
    @user = User[1]
  end
end
```

Before we start using the BlueForm helper there's one thing to remember, it's first 
argument should ALWAYS be set. If you're storing your form data in an object you can set 
that object as the first argument, otherwise you can just set it to nil. In the above 
snippet we're retrieving a fictional user with an ID of 1. Let's create our view so we can 
show a form with the user details.

    #{
      form_for(@user, :method => :post, :action => '/save') do |f|
        f.input_text 'Name', :name
      end
    }

As you can see the form_for method uses a block in which we call methods from the "f" 
object. It's important to remember that all methods (including the block itself) return 
the HTML rather than outputting it so be sure to wrap it in the correct tags (#{} in case 
of Etanni). As you might've noticed I'm not adding anything else than a label and a name 
for the field, this is the power of BlueForm; it retrieves the data from the @user object 
we passed as the first argument. In case you want to override that value you can usually 
use a hash as the third argument in which you specify a key "value" with your custom 
value.

    #{
      form_for(@user, :method => :post, :action => '/save') do |f|
        f.input_text 'Name', :name, :value => 'Chuck Norris'
      end
    }

But that's not all, if your object (@user) responds to a method "errors" that will be 
used to retrieve the erros for each field. These errors will be wrapped in a span tag 
(with a class of "error") and inserted in the label tag.

One thing to remember with this is that if you're submitting form data and then using a 
redirect you'll have to store the errors in the flash under the key "form_errors":

```ruby
require 'ramaze'
require 'sequel'

class Main < Ramaze::Controller
  map '/'
  helper :blue_form

  def index
    @user = User[1]
  end

  def save
    @user = User[1]

    begin
      @user.update(request.params['name'])
    rescue
      flash[:form_errors] = @user.errors # <= we're storing the errors so they don't get lost
    end

    redirect Main.r(:index)
  end
end
```

And that's about it, the BlueForm helper is really easy to use actually.
