require "rouge"

# Rouge marks lazy lexers as loaded before their dictionaries are available.
# Initialize them at boot, before concurrent article/search requests can race.
Rouge.eager_load!
