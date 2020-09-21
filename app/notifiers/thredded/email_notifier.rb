# frozen_string_literal: true

module Thredded
  class EmailNotifier
    def initialize
      fail 'Please set Thredded.email_from in config/initializers/thredded.rb' if Thredded.email_from.blank?
    end

    def human_name
      I18n.t('thredded.email_notifier.by_email')
    end

    def key
      'email'
    end

    def new_post(post, users)
      Thredded::PostMailer.post_notification(post.id, users.map(&:email)).deliver_now
    end

    def new_private_post(post, users)
      Thredded::PrivateTopicMailer.message_notification(post.id, users.map(&:email)).deliver_now
    end
  end
end
