# Who is making a change in this request, when it matters to the models: an
# edit made by a person in the admin is marked as theirs (a hand-edited
# translation, later an admin event).
class Current < ActiveSupport::CurrentAttributes
  attribute :editor
end
