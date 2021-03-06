require 'json'
require 'rbconfig'

class PuppetDB::Config
  def initialize(overrides = nil, load_files = false)
    @overrides = {}
    overrides.each { |k, v| @overrides[k.to_sym] = v } unless overrides.nil?

    @load_files = load_files
  end

  def windows?
    @is_windows ||= (RbConfig::CONFIG['host_os'] =~ %r{mswin|mingw|cygwin})
    @is_windows
  end

  def load_file(path)
    loaded_conf = File.open(path) { |f| JSON.parse(f.read, symbolize_names: true)[:puppetdb] }

    # Munge token-file into token_file for better readability in Ruby
    if loaded_conf[:'token-file']
      loaded_conf[:token_file] = loaded_conf.delete(:'token-file')
    end

    loaded_conf
  end

  def puppetlabs_root
    if windows?
      'C:\ProgramData\PuppetLabs'
    else
      '/etc/puppetlabs'
    end
  end

  def global_conf
    File.join(puppetlabs_root, 'client-tools', 'puppetdb.conf')
  end

  def user_root
    File.join(Dir.home, '.puppetlabs')
  end

  def user_conf
    File.join(user_root, 'client-tools', 'puppetdb.conf')
  end

  def default_cacert
    File.join(puppetlabs_root, 'puppet', 'ssl', 'certs', 'ca.pem')
  end

  def defaults
    {
      cacert: default_cacert,
      token_file: File.join(user_root, 'token')
    }
  end

  def load_config
    config = defaults
    if @load_files
      if File.exist?(global_conf) && File.readable?(global_conf)
        config = config.merge(load_file(global_conf))
      end

      if @overrides[:config_file]
        config = config.merge(load_file(@overrides[:config_file]))
      elsif File.exist?(user_conf) && File.readable?(user_conf)
        config = config.merge(load_file(user_conf))
      end
    end

    config.merge(@overrides)
  end

  def config
    @config ||= load_config
  end

  def load_token
    if @config.include?(:token)
      @config[:token]
    elsif File.readable?(config[:token_file])
      File.read(config[:token_file]).strip
    end
  end

  def token
    @token ||= load_token
  end

  def server_urls
    return config[:server_urls].split(',') if config[:server_urls].is_a?(String)
    config[:server_urls] || []
  end

  def pem
    @config.select { |k, _| [:cacert, :cert, :key].include?(k) }
  end

  def [](key)
    @config[key]
  end
end
