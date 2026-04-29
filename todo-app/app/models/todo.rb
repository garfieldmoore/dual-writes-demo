class Todo < ApplicationRecord
  include Discard::Model

  validates :title, presence: true

  after_create :notify_search_app
  after_update :notify_search_app
  after_discard :notify_search_app_deleted
  after_undiscard :notify_search_app_active

  private

  def notify_search_app
    SearchSyncService.notify_created(id)
  end

  def notify_search_app_deleted
    SearchSyncService.notify_deleted(id)
  end

  def notify_search_app_active
    SearchSyncService.notify_created(id)
  end
end
