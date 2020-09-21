# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'thredded/messageboards/index' do
  before do
    # Give view access to route helpers and general helper methods
    view.extend Thredded::Engine.routes.url_helpers
    view.extend Thredded::ApplicationHelper

    # Set up instance variables
    assign(:messageboards, [])
    assign(:groups, [])

    # Stub the helper methods defined in the controller
    allow(view).to(
      receive_messages(
        active_users: [],
        messageboard_or_nil: nil,
        thredded_moderator?: false,
        thredded_signed_in?: true,
        unread_private_topics_count: 1,
        unread_topics_count: 0,
      )
    )

    # Stub the policy, so we can test the view given different permissions
    allow(view).to receive(:policy).and_return(instance_double(Thredded::MessageboardPolicy))
  end

  it 'shows the Create button when permitted to create a messageboard' do
    expect(view.policy).to receive(:create?).and_return(true).twice

    render

    expect(rendered).to have_link(I18n.t('thredded.messageboard.create'))
    expect(rendered).to have_link(I18n.t('thredded.messageboard_group.create'))
  end

  it 'does not show the Create button when not permitted to create a messageboard' do
    expect(view.policy).to receive(:create?).and_return(false).twice

    render

    expect(rendered).not_to have_link(I18n.t('thredded.messageboard.create'))
    expect(rendered).not_to have_link(I18n.t('thredded.messageboard_group.create'))
  end
end
