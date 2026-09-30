class ApplicationMailer < ActionMailer::Base
  default from: ENV.fetch("MAILER_FROM", "Usput.ba <no-reply@usput.ba>")
  layout "mailer"
end
