class FlyingSphinx::Configuration
  attr_reader :identifier, :api_key, :host, :port, :database_port, :mem_limit

  def initialize(identifier = nil, api_key = nil)
    @identifier = identifier || identifier_from_env
    @api_key    = api_key    || api_key_from_env

    set_from_server
    setup_environment_settings
  end

  def api
    @api ||= FlyingSphinx::API.new(identifier, api_key)
  end

  def sphinx_configuration
    thinking_sphinx.generate
    set_database_settings

    riddle.render
  end

  def start_sphinx
    api.post('start')
  end

  def stop_sphinx
    api.post('stop')
  end

  private

  def set_from_server
    response = api.get('/', {}, { :json => true })
    raise 'Invalid Flying Sphinx credentials' if response.status == 403

    @host          = response.body.server
    @port          = response.body.port
    @database_port = response.body.database_port
    @mem_limit     = response.body.mem_limit
  end

  def base_path
    "/mnt/sphinx/flying-sphinx/#{identifier}"
  end

  def log_path
    "#{base_path}/log"
  end

  def thinking_sphinx
    ThinkingSphinx::Configuration.instance
  end

  def riddle
    thinking_sphinx.configuration
  end

  def setup_environment_settings
    ThinkingSphinx.remote_sphinx = true

    set_searchd_settings
    set_indexer_settings
    set_path_settings
  end

  def set_path_settings
    thinking_sphinx.searchd_file_path = "#{base_path}/indexes"

    riddle.searchd.pid_file  = "#{base_path}/searchd.pid"
    riddle.searchd.log       = "#{log_path}/searchd.log"
    riddle.searchd.query_log = "#{log_path}/searchd.query.log"
  end

  def set_searchd_settings
    thinking_sphinx.port    = port
    thinking_sphinx.address = host
  end

  def set_indexer_settings
    riddle.indexer.mem_limit = mem_limit.to_s + 'M'
  end

  def set_database_settings
    riddle.indexes.each do |index|
      next unless index.respond_to?(:sources)

      index.sources.each do |source|
        source.sql_host = '127.0.0.1'
        source.sql_port = database_port
      end
    end
  end

  def identifier_from_env
    ENV['FLYING_SPHINX_IDENTIFIER']
  end

  def api_key_from_env
    ENV['FLYING_SPHINX_API_KEY']
  end
end
