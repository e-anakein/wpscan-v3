module WPScan
  module Controller
    # Specific Core controller to include WordPress checks
    class Core < CMSScanner::Controller::Core
      # @return [ Array<OptParseValidator::Opt> ]
      def cli_options
        [OptURL.new(['--url URL'], required_unless: :update, default_protocol: 'http')] +
          super.drop(1) + # delete the --url from CMSScanner
          [
            OptChoice.new(['--server SERVER',
                           'Force the supplied server module to be loaded, '\
                           'available modules: apache (default), iis, nginx'],
                          choices: %w(apache iis nginx),
                          normalize: [:downcase, :to_sym]),
            OptBoolean.new(['--force', 'Do not check if the target is running WordPress']),
            OptBoolean.new(['--update', 'Update the Database'], required_unless: :url)
          ]
      end

      def local_db
        @local_db ||= DB::Updater.new(DB_DIR)
      end

      def before_scan
        output('banner')

        if parsed_options[:update] || local_db.missing_files?
          output('db_update_started')
          output('db_update_finished', updated: local_db.update, verbose: parsed_options[:verbose])

          exit(0) unless parsed_options[:url]
        end

        super(false) # disable banner output

        DB.init_db

        load_server_module

        fail NotWordPressError unless target.wordpress? || parsed_options[:force]
      end

      # Loads the related server module in the target
      # and includes it in the WpItem class which will be needed
      # to check if directory listing is enabled etc
      #
      # @return [ Symbol ] The server module loaded
      def load_server_module
        server = target.server || :Apache # Tries to auto detect the server

        # Force a specific server module to be loaded if supplied
        case parsed_options[:server]
        when :apache
          server = :Apache
        when :iis
          server = :IIS
        when :nginx
          server = :Nginx
        end

        mod = CMSScanner::Target::Server.const_get(server)

        target.extend mod
        WPScan::WpItem.include mod

        server
      end
    end
  end
end