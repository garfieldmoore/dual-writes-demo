class SearchSyncService
  SEARCH_APP_URL = ENV.fetch('SEARCH_APP_URL', 'http://localhost:3001')

  def self.notify_created(id)
    post_to_search_app(id, 'created')
  end

  def self.notify_updated(id)
    post_to_search_app(id, 'updated')
  end

  def self.notify_deleted(id)
    post_to_search_app(id, 'deleted')
  end

  private

  def self.post_to_search_app(id, action)
    conn = Faraday.new(url: SEARCH_APP_URL)
    conn.post('/webhook/todos', JSON.generate({ id:, action: }), { 'Content-Type' => 'application/json' })
  rescue StandardError => e
    Rails.logger.warn("Failed to sync with search app: #{e.message}")
  end
end
