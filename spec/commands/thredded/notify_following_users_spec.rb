# frozen_string_literal: true

require 'spec_helper'

module Thredded
  describe NotifyFollowingUsers do
    describe '#targeted_users' do
      subject(:targeted_users) { NotifyFollowingUsers.new(post).targeted_users(notifier) }

      let(:post) { create(:post, user: poster, postable: topic) }
      let(:poster) { create(:user, name: 'poster') }
      let!(:follower) { create(:user_topic_follow, user: create(:user, name: 'follower'), topic: topic).user }
      let(:topic) { create(:topic, messageboard: messageboard) }
      let!(:messageboard) { create(:messageboard) }
      let(:notifier) { EmailNotifier.new }

      before do
        # Creating a post will trigger the NotifyFollowingUsers job, creating UserPostNotification records.
        # Create the post and then delete all the created UserPostNotification records for testing.
        post
        Thredded::UserPostNotification.destroy_all
      end

      it 'includes followers where preference to receive these notifications' do
        create(:notifications_for_followed_topics,
               notifier_key: 'email',
               user: follower,
               enabled: true)

        expect(targeted_users).to include(follower)
      end

      it 'excludes followers that have already been notified' do
        expect(Thredded::UserPostNotification.create_from_post_and_user(post, follower)).to be_truthy
        expect(targeted_users).not_to include(follower)
      end

      it "doesn't include the poster, even if they follow" do
        expect(UserTopicFollow.find_by(user_id: poster.id, topic_id: topic.id)).not_to be_nil
        expect(targeted_users).not_to include(poster)
      end

      context "when a follower's email notification is turned off" do
        before do
          create(:notifications_for_followed_topics,
                 notifier_key: 'email',
                 user: follower,
                 enabled: false)
        end

        it "doesn't include that user" do
          expect(targeted_users).not_to include(follower)
        end

        context 'with the MockNotifier' do
          let(:notifier) { MockNotifier.new }

          it 'does include that user' do
            expect(targeted_users).to include(follower)
          end
        end
      end

      context "when a follower's 'mock' notification is turned off (per messageboard)" do
        before do
          create(:messageboard_notifications_for_followed_topics,
                 notifier_key: 'mock',
                 messageboard: messageboard,
                 user: follower,
                 enabled: false)
        end

        context 'with the EmailNotifier' do
          let(:notifier) { EmailNotifier.new }

          it 'does includes that user' do
            expect(targeted_users).to include(follower)
          end
        end

        context 'with the MockNotifier' do
          let(:notifier) { MockNotifier.new }

          it "doesn't include that user" do
            expect(targeted_users).not_to include(follower)
          end
        end
      end

      context "when a follower's 'mock' notification is turned off (overall)" do
        before do
          create(:notifications_for_followed_topics,
                 notifier_key: 'mock',
                 user: follower,
                 enabled: false)
        end

        context 'with the EmailNotifier' do
          let(:notifier) { EmailNotifier.new }

          it 'does includes that user' do
            expect(targeted_users).to include(follower)
          end
        end

        context 'with the MockNotifier' do
          let(:notifier) { MockNotifier.new }

          it "doesn't include that user" do
            expect(targeted_users).not_to include(follower)
          end
        end
      end
    end

    describe '#run' do
      let(:post) { create(:post) }

      let(:command) { NotifyFollowingUsers.new(post) }
      let(:targeted_users) { [create(:user)] }

      before { allow(command).to receive(:targeted_users).and_return(targeted_users) }

      it 'sends email' do
        expect { command.run }.to change { ActionMailer::Base.deliveries.count }
        # see EmailNotifier spec for more detailed specs
      end

      context 'with the MockNotifier', thredded_reset: [:@notifiers] do
        let(:mock_notifier) { MockNotifier.new }

        before { Thredded.notifiers = [mock_notifier] }

        it "doesn't send any emails" do
          expect { command.run }.not_to change { ActionMailer::Base.deliveries.count }
        end
        it 'notifies exactly once' do
          expect { command.run }.to change(mock_notifier, :users_notified_of_new_post)
          expect { command.run }.not_to change(mock_notifier, :users_notified_of_new_post)
        end
      end

      context 'with multiple notifiers', thredded_reset: [:@notifiers] do
        let(:mock_notifier1) { MockNotifier.new }
        let(:mock_notifier2) { MockNotifier.new }

        before { Thredded.notifiers = [mock_notifier1, mock_notifier2] }

        def count_users_for_each_notifier
          [mock_notifier1.users_notified_of_new_post.length, mock_notifier2.users_notified_of_new_post.length]
        end
        it 'notifies via all notifiers' do
          expect { command.run }
            .to change { count_users_for_each_notifier }.from([0, 0]).to([1, 1])
        end
        it "second run doesn't notify" do
          command.run
          expect { command.run }
            .not_to change { count_users_for_each_notifier }
        end
      end
    end
  end
end
