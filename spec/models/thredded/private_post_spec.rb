# frozen_string_literal: true

require 'spec_helper'

module Thredded
  describe PrivatePost do
    let(:private_topic) { create(:private_topic, user: sally, users: [jane, erik]) }
    let(:sally) { create(:user) }
    let(:jane) { create(:user) }
    let(:erik) { create(:user) }

    it 'notifies members on create' do
      private_post = build(:private_post, postable: private_topic, user: jane)
      notifier = instance_double(NotifyPrivateTopicUsers)
      expect(NotifyPrivateTopicUsers).to receive(:new).with(private_post).and_return(notifier)
      expect(notifier).to receive(:run)
      private_post.save!
    end
  end

  describe PrivatePost, '#page' do
    subject(:post_page) { private_post.page(per_page: 1) }

    let(:private_topic) { create(:private_topic, user: sally, users: [jane]) }
    let(:sally) { create(:user) }
    let(:jane) { create(:user) }

    let(:private_post) { create(:private_post, postable: private_topic, id: 100) }

    it 'for sole private_post' do
      expect(post_page).to eq(1)
    end
    it 'for two private_posts' do
      travel_to 1.hour.ago do
        create(:private_post, postable: private_topic, id: 99)
      end
      expect(post_page).to eq(2)
    end
    describe 'with different per_page' do
      subject(:post_page) { private_post.page(per_page: 2) }

      it 'respects per' do
        travel_to 1.hour.ago do
          create(:private_post, postable: private_topic, id: 99)
        end
        expect(post_page).to eq(1)
      end
    end

    it 'with previous posts with disordered ids' do
      travel_to 2.hours.ago do
        create(:private_post, postable: private_topic, id: 101)
      end
      travel_to 1.hour.ago do
        create(:private_post, postable: private_topic, id: 99)
      end
      expect(post_page).to eq(3)
    end
  end

  describe PrivatePost, '#mark_as_unread' do
    let(:user) { create(:user) }
    let(:private_topic) { create(:private_topic, user: user) }
    let(:first_post) { create(:private_post, postable: private_topic) }
    let(:second_post) { create(:private_post, postable: private_topic) }
    let(:third_post) { create(:private_post, postable: private_topic) }
    let(:read_state) do
      create(:user_private_topic_read_state,
             postable: private_topic,
             user: user, read_at: third_post.created_at)
    end
    let(:page) { 1 }

    before do
      travel_to 2.days.ago do
        first_post
      end
      travel_to 1.day.ago do
        second_post
      end
      travel_to 1.minute.ago do
        third_post
        read_state
      end
    end

    context 'when first post' do
      it 'removes the read state' do
        expect do
          first_post.mark_as_unread(user)
        end.to change { private_topic.reload.user_read_states.count }.by(-1)
      end
    end

    context 'when third (say) post' do
      it 'changes the read state to the previous post' do
        expect do
          third_post.mark_as_unread(user)
        end.to change { read_state.reload.read_at }.to eq second_post.created_at
      end
    end

    context 'when none are read (no ReadState at all)' do
      let(:read_state) { nil }

      it 'marking first post as unread does nothing' do
        expect do
          first_post.mark_as_unread(user)
        end.not_to change { private_topic.reload.user_read_states.count }
      end
      it 'marking third post as unread creates read state' do
        expect do
          third_post.mark_as_unread(user)
        end.to change { private_topic.reload.user_read_states.count }
      end
    end

    context 'when read up to first post' do
      let(:read_state) do
        create(:user_private_topic_read_state,
               postable: private_topic,
               user: user,
               read_at: first_post.created_at)
      end

      it 'marking the third post as unread changes read state to second post' do
        expect do
          third_post.mark_as_unread(user)
        end.to change { read_state.reload.read_at }.to eq second_post.created_at
      end
    end
  end
end
