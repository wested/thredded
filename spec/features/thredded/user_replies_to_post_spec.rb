# frozen_string_literal: true

require 'spec_helper'

RSpec.feature 'User replying to topic' do
  let!(:posts) { posts_exist_in_a_topic }
  let(:post) { posts.first_post }

  def login_and_visit_posts
    user.log_in
    posts.visit_posts
  end

  it 'adds a new reply' do
    login_and_visit_posts
    expect { posts.submit_reply }.to change { posts.posts.size }.by(1)
    expect(posts).to have_new_reply
  end

  it 'starts a quote-reply (no js)' do
    login_and_visit_posts
    post.start_quote
    expect(page).to have_current_path(posts.quote_page_for_first_post)
    expect(posts.post_form.content).to(start_with('>').and(end_with("\n\n")))
  end

  it 'starts a quote-reply (js)', js: true do
    login_and_visit_posts
    post.start_quote
    # Expect current path to not change because the JS magic takes place
    expect(page).to have_current_path(current_path)
    # Wait for the async quote content fetch completion
    Timeout.timeout(2) do
      loop do
        break if posts.post_form.content != '...' && !posts.post_form.content.empty?
        sleep(0.2)
      end
    end
    expect(posts.post_form.content).to(start_with('>').and(end_with("\n\n")))
  end

  context 'using dropdown', js: true do
    shared_examples_for 'user can be mentioned' do
      it 'can be mentioned' do
        login_and_visit_posts
        expect(page).not_to have_css('.thredded--textcomplete-dropdown')
        sleep(0.2)
        posts.start_reply("Hey @#{other_user.name[0..2]}")
        sleep(0.2)
        expect(page).to have_css('.thredded--textcomplete-dropdown')
        find('.thredded--textcomplete-dropdown .textcomplete-item.active').click
        expect(find_field('Content').value).to include(other_user_mention)
        expect(page).not_to have_css('.thredded--textcomplete-dropdown')
      end
    end

    context '(with a user with space in their name)' do
      it_behaves_like 'user can be mentioned' do
        let!(:other_user) { create(:user, name: 'Han Solo') }
        let(:other_user_mention) { '@"Han Solo"' }
      end
    end

    context '(with a user without a space)' do
      it_behaves_like 'user can be mentioned' do
        let!(:other_user) { create(:user, name: 'Chewie') }
        let(:other_user_mention) { '@Chewie' }
      end
    end
  end

  def user
    user = create(:user, name: 'C-3PO')
    PageObject::User.new(user)
  end

  def messageboard
    @messageboard ||= create(:messageboard)
  end

  def posts_exist_in_a_topic
    posts_owner = create(:user, name: 'R2D2')
    topic = create(:topic,
                   with_posts: 2,
                   messageboard: messageboard,
                   user: posts_owner,
                   last_user: posts_owner)
    PageObject::Posts.new(topic.posts)
  end
end
