module RubyInstaller
module Runtime
  # :nodoc:
  module Ridk
    class << self
      include Colors

      def run!(args)
        enable_colors
        case args[0]
          when 'install'
            print_logo
            puts
            install(args[1..-1])
          when 'enable', 'exec'
            puts Runtime.msys2_installation.enable_msys_apps_per_cmd
          when 'disable'
            puts Runtime.msys2_installation.disable_msys_apps_per_cmd
          when 'enableps1', 'execps1'
            puts Runtime.msys2_installation.enable_msys_apps_per_ps1
          when 'disableps1'
            puts Runtime.msys2_installation.disable_msys_apps_per_ps1
          when 'version'
            print_version
          when 'help', '--help', '-?', '/?', nil
            print_logo
            print_help
          else
            $stderr.puts "Invalid option #{args[0].inspect}"
        end
      end

      # The ASCII art is thankfully generated by:
      # http://patorjk.com/software/taag/#p=display&f=Big&t=RubyInstaller2
      # http://patorjk.com/software/taag/#p=display&f=Bigfig&t=for%20Windows
LOGO = %q{
 _____       _          r _____           _        _ _        ry ___  y
|  __ \     | |         r|_   _|         | |      | | |       ry|__ \ y
| |__) |   _| |__  _   _ r | |  _ __  ___| |_ __ _| | | ___ _ __ry ) |y
|  _  / | | | '_ \| | | |r | | | '_ \/ __| __/ _` | | |/ _ \ '__ry/ / y
| | \ \ |_| | |_) | |_| |r_| |_| | | \__ \ || (_| | | |  __/ | ry/ /_ y
|_|  \_\__,_|_.__/ \__, r|_____|_| |_|___/\__\__,_|_|_|\___|_|ry|____|y
                    __/ |   c        _                              c
                   |___/    c      _|_ _  __   | | o __  _| _     _ c
                            c       | (_) |    |^| | | |(_|(_)\^/_> c
}[1..-1]

      def print_logo
        puts  LOGO.gsub(/r(.*?)r/){ magenta($1) }
                  .gsub(/y(.*?)y/){ cyan($1) }
                  .gsub(/c(.*?)c/){ yellow($1) }
      end

      DEFAULT_COMPONENTS = %w[1 3]

      def install(args)
        ci = ComponentsInstaller.new
        inst_defaults = DEFAULT_COMPONENTS

        if args.empty?
          # Interactive installation
          loop do
            ci.installable_components.each do |comp|
              puts format("  % 2d - %s", comp.task_index, comp.description)
            end
            puts
            print "Which components shall be installed? If unsure press ENTER [#{inst_defaults.join(",")}] "

            inp = STDIN.gets
            inp = inp.tr(",", " ").strip if inp
            if !inp
              break
            elsif inp.empty? && inst_defaults.empty?
              break
            elsif inp.empty?
              inst_list = inst_defaults
            elsif inp =~ /\A(?:(\d+|\w+)\s*)+\z/
              inst_list = [inp]
            else
              puts red("Please enter a comma separated list of the components to be installed")
            end

            if inst_list
              puts
              begin
                ci.install(args_to_tasks(ci, inst_list).map(&:name))
              rescue => err
                puts red("Installation failed: #{err}")
              end

              ci.reload
              inst_defaults = []
              puts
            end
          end

        else
          # Unattended installation
          ci.install(args_to_tasks(ci, args).map(&:name))
        end
      end

      private def args_to_tasks(ci, args)
        tasks = args.join(" ").split(" ").map do |idx_or_name|
          if idx_or_name =~ /\A\d+\z/ && (task=ci.installable_components.find{|c| idx_or_name.to_i == c.task_index })
            task
          elsif idx_or_name =~ /\A\w+\z/ && (task=ci.installable_components.find{|c| idx_or_name == c.name })
            task
          else
            puts red("Can not find component #{idx_or_name.inspect}")
          end
        end.compact
      end

      def msys_version_info(msys_path)
        require "rexml/document"
        doc = File.open( File.join(msys_path, "components.xml") ) do |fd|
          REXML::Document.new fd
        end
        {
          "title" => doc.elements.to_a("//Packages/Package/Title").first.text,
          "version" => doc.elements.to_a("//Packages/Package/Version").first.text,
        }
      end

      private def ignore_err
        orig_verbose, $VERBOSE = $VERBOSE, nil
        begin
          yield
        rescue
        end
        $VERBOSE = orig_verbose
      end

      def print_version
        require "yaml"
        require "rbconfig"

        h = {
          "ruby" => { "path" => RbConfig::TOPDIR,
                      "version" => RUBY_VERSION,
                      "platform" => RUBY_PLATFORM,
                      "cc" => RbConfig::CONFIG['CC_VERSION_MESSAGE'].split("\n", 2).first },
          "ruby_installer" => { "package_version" => RubyInstaller::Runtime::PACKAGE_VERSION,
                                "git_commit" => RubyInstaller::Runtime::GIT_COMMIT },
        }

        ignore_err do
          msys = Runtime.msys2_installation
          msys.enable_msys_apps(if_no_msys: :raise)

          msys_ver = ignore_err{ msys_version_info(msys.msys_path) }
          h["msys2"] = { "path" => msys.msys_path }.merge(msys_ver || {})
        end

        ignore_err do
          cc = RbConfig::CONFIG['CC']
          ver, _ = `#{cc} --version`.split("\n", 2)
          h["cc"] = ver
        end

        ignore_err do
          ver, _ = `sh --version`.split("\n", 2)
          h["sh"] = ver
        end

        ignore_err do
          h["os"] = `ver`.strip
        end

        puts h.to_yaml
      end

      def print_help
        $stdout.puts <<-EOT
Usage:
    #{$0} [option]

Option:
    install                   Install MSYS2 and MINGW dev tools
    exec <command>            Execute a command within MSYS2 context
    enable                    Set environment variables for MSYS2
    disable                   Unset environment variables for MSYS2
    version                   Print RubyInstaller and MSYS2 versions
    use                       Switch to a different ruby version
    help | --help | -? | /?   Display this help and exit
EOT
      end
    end
  end
end
end
