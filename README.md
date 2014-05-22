# cloudamize cookbook

# Requirements

None at present

# Usage

include_recipe 'cloudamize::default'

# Attributes

Set [:cloudamize][:customer_key] to your account key value. Due to the way this
attribute is used by the cookbook, changes applied after installing the agent on
a node will NOT change the customer key of the previously installed agent.

# Recipes

## default

Installs the agent via script

# Author

Author:: Travis Truman (trumant@gmail.com)
