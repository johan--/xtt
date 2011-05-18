class StatusObserver < ActiveRecord::Observer

  def after_create(status)
    unless status.source == "import"
    project = status.project
    if project.nil? # user id "out", see if there's anyone who needs to know
      if status.previous && status.previous.project
        project = status.previous.project # ah, the last project will want to know about this!
      end
    end

    return unless project
    project.tendrils.each do |tendril|
      next if tendril.notifies.nil? # usually this is caused by bad data or missing foreign object (aka no 'campfire')

      # Round the message. If it was more than a few hours, we probably don't care
      # about the exact number of minutes.
      if status.created_at.utc < 4.hours.ago.utc
        timing = ((Time.now - status.created_at) / 1.hour).to_i
        tense = "was (~#{timing} hours ago)"        
      elsif status.created_at.utc < 1.minute.ago.utc
        timing = ((Time.now - status.created_at) / 1.minute).to_i
        tense = "was (#{timing} mins ago)"
      else
        tense = "" # nothing. fuck you.
        # ..
        #
        # I'm sorry, baby. Don't be like that.
      end
      if status.out?
        previous = status.previous
        tendril.notifies.send_message "[XTT] #{status.user.login} #{tense} out, and no longer working on #{status.previous.project.name}: '#{status.message}'"
      else
        project = status.previous && status.previous.project
        if project && project != status.project
          tendril.notifies.send_message "[XTT] #{status.user.login} switched projects, and #{tense} now \"#{status.message}\" on #{status.project.name}"
        elsif project.nil?
          tendril.notifies.send_message "[XTT] #{status.user.login} #{tense} back, \"#{status.message}\" on #{status.project.name}"
        else
          tendril.notifies.send_message "[XTT] #{status.user.login} #{tense} now \"#{status.message}\" still on #{status.project.name}"
        end
      end
    end
    # Bj.submit %{/usr/bin/env rake tt:notify STATUS=#{status.id}}, :rails_env => RAILS_ENV, :tag => "notifies"
  end
end
end