#!/usr/bin/env ruby

# VUM - Vim plUgin Manager
# This downloads/updates/deletes vim plugins that are managed via git

require 'rubygems'
require 'fileutils'

# extending String class to display strings in color
class String
  def color(color_code); "\e[0;#{color_code}m#{self}\e[0m"; end
  def bold_color(color_code); "\e[1;#{color_code}m#{self}\e[0m"; end
  def underscore_color(color_code); "\e[4;#{color_code}m#{self}\e[0m"; end

  def red; color(31); end
  def green; color(32); end
  def yellow; color(33); end
  def blue; color(34); end

  def bold_red; bold_color(31); end
  def bold_green; bold_color(32); end
  def bold_yellow; bold_color(33); end
  def bold_blue; bold_color(34); end

  def underscore_red; underscore_color(31); end
  def underscore_green; underscore_color(32); end
  def underscore_yellow; underscore_color(33); end
  def underscore_blue; underscore_color(34); end
end

# main Vum class
class Vum
  attr_reader :repolist, :ok_repolist, :failed_repolist, :download_ok_count, :download_failed_count,
    :skipped_plugin_count

  attr_accessor :existing_plugins

  VUM_REPOS_FILE = ENV["HOME"] + "/.vum_repos"
  VUM_MAIN_MENU_CHANGE_PLUGIN_INSTALL_DIR = 1
  VUM_MAIN_MENU_INSTALL_WITHOUT_CHECK = 2
  VUM_MAIN_MENU_INSTALL_WITH_CHECK = 3
  VUM_MAIN_MENU_CHECK = 4
  VUM_MAIN_MENU_UPDATE = 5

  @@plugins_dir = ENV["HOME"] + "/.vim/bundle"

  def initialize
    setup
  end

  def setup
    @repolist = get_repolist_from_file # this is an array of hashes { :repo_site :plugin_name }
    @existing_plugins = [] # current updatable plugins in bundle directory { :plugin_name, :repo_site, :dir }
    @ok_repolist = []
    @failed_repolist = []
    @download_ok_count = 0
    @download_failed_count = 0
    @skipped_plugin_count = 0
  end

  # accessor for @@plugins_dir
  def self.plugins_dir
    @@plugins_dir
  end

  # mutator for @@plugins_dir
  def self.plugins_dir=(val)
    @@plugins_dir = val
  end

  def get_repolist_from_file
    @repolist = []
    if File.exists?(VUM_REPOS_FILE)
      File.open(VUM_REPOS_FILE, 'r').each_line do |line|
        repo_line = line.chomp
        @repolist << { :plugin_name => get_plugin_name(repo_line), :repo_site => repo_line }
      end

      unless @repolist.empty?
        sort_repolist_by_plugin_name(@repolist)
      end
    end
  end

  def install_plugins_with_check
    puts
    puts "Checking for repository existence"
    puts
    check_for_repo_existence

    puts
    puts "  #{@ok_repolist.length}/#{@repolist.length}" +
      " repositories seem to be good enough for downloading" if @ok_repolist.length > 0

    puts "  #{@failed_repolist.length}/#{@repolist.length}" +
      " repositories were found to have some troubles" +
      " and vum will not use those repositories for downloading" if @failed_repolist.length > 0

    print "Proceed [y/n] ? "
    answer = gets.chomp.downcase
    return unless answer == "y" or answer == "yes"

    download_plugins
  end

  def install_plugins_without_check
    @ok_repolist = @repolist
    download_plugins
  end

  def check_for_repo_existence
    @ok_repolist.clear
    @failed_repolist.clear
    #
    # get maximum reposite name
    max_repo_plugin_site_name_length = get_max_repo_line_length(@repolist)
    @repolist.each do |repo|
      padding_length = max_repo_plugin_site_name_length + 4 -
        repo[:repo_site].length - repo[:plugin_name].length

      `git ls-remote #{repo[:repo_site]} 2>/dev/null 1>&2`
      if $?.exitstatus == 0
        @ok_repolist << repo
        puts "  #{repo[:plugin_name]}".bold_green + " (" + "#{repo[:repo_site]}".underscore_blue + ") " +
          ("." * padding_length) + " [   "+ "OK".bold_green + "   ]"
      else
        @failed_repolist << repo
        puts "  #{repo[:plugin_name]}".bold_red + " (" + "#{repo[:repo_site]}".underscore_blue + ") " +
          ("." * padding_length) + " [ "+ "FAILED".bold_red + " ]"
      end
    end
  end

  def download_plugins
    puts
    puts "Plugins download starts"
    puts

    max_repo_plugin_site_name_length = get_max_repo_line_length(@ok_repolist)

    @ok_repolist.each_with_index do |repo, index|

      padding_length = max_repo_plugin_site_name_length - (index + 1).to_s.length + 2 -
        repo[:repo_site].length - repo[:plugin_name].length

      unless plugin_directory_exists?(repo, index)
        `git clone #{repo[:repo_site]} 2>/dev/null 1>&2`
        if $?.exitstatus == 0
          print "  (#{index + 1}/#{@ok_repolist.length}) Downloading " +
            "#{repo[:plugin_name]}".bold_green + " from " + "#{repo[:repo_site]}".underscore_blue +
            " " + "." * padding_length
          puts " [   " + "OK".bold_green + "   ]"

          @download_ok_count += 1
        else
          print "  (#{index + 1}/#{@ok_repolist.length}) Downloading " +
            "#{repo[:plugin_name]}".bold_red + " from " + "#{repo[:repo_site]}".underscore_blue +
            " " + "." * padding_length
          puts " [ " + "FAILED".bold_red + " ]"

          @download_failed_count += 1
        end
      end
    end
  end

  def plugin_directory_exists?(repo, index)
    dir = repo[:repo_site].match(/.*\/(\S*)/)[1].to_s.strip.gsub(/\.git/, "")
    if Dir.exists?(dir)
      puts "  (#{index + 1}/#{@ok_repolist.length}) " +
        "Skip downloading #{repo[:plugin_name]} (already exists)...".bold_blue
      @skipped_plugin_count += 1
      return true
    end
    return false
  end

  def get_updatable_plugin_list
    @existing_plugins = []
    Dir.glob(File.expand_path(Vum.plugins_dir) + "/*").each do |dir|
      Dir.chdir(dir)
      if Dir.exists?(".git")
        repo_line = `git remote -v | grep -e "fetch)$" | tr '\t' ' ' | cut -d " " -f 2`
        @existing_plugins << { :dir => dir, :plugin_name => get_plugin_name(repo_line), :repo_site => get_repo_site(repo_line) }
      end
    end

    unless @existing_plugins.empty?
      @existing_plugins = @existing_plugins.sort_by { |plugin| plugin[:plugin_name] }
      max_length_plugin_name = @existing_plugins.max_by { |plugin| plugin[:plugin_name].length }

      @existing_plugins.each_with_index do |plugin, index|
        if (index + 1) % 2 != 0
          padding_length = max_length_plugin_name[:plugin_name].length - plugin[:plugin_name].length + 6 -
            (index + 1).to_s.length
          print "  #{index + 1}".bold_yellow + ". #{plugin[:plugin_name]}" + " " * padding_length
        else
          puts "  #{index + 1}".bold_yellow + ". #{plugin[:plugin_name]}"
        end
      end

    else
      puts "  There are no updatable plugins in the bundle directory"
    end

    puts "\n  " + "A".bold_yellow + ". All" if @existing_plugins.count > 1
  end

  def get_plugin_name(line)
    line.match(/.*\/(\S*)/)[1].to_s.strip.capitalize.gsub(/\..*/, "")
  end

  def get_repo_site(line)
    line.match(/http\S*\s/).to_s.strip
  end

  def sort_repolist_by_plugin_name(repolist)
    repolist.sort_by { |repo| repo[:plugin_name] }
  end

  def get_max_repo_line_length(repolist)
    max_repo_plugin_site_name_length = 0
    repolist.each do |repo|
      if (repo[:repo_site].length + repo[:plugin_name].length) > max_repo_plugin_site_name_length
        max_repo_plugin_site_name_length = repo[:repo_site].length + repo[:plugin_name].length
      end
    end
    max_repo_plugin_site_name_length
  end

  def print_download_summary
    if @download_ok_count > 0
      puts "  #{@download_ok_count}/#{@repolist.length} plugins were downloaded successfully"
    end
    if @download_failed_count > 0
      puts "  #{@download_failed_count}/#{@repolist.length} plugins " +
        "failed during downloading for some reason"
    end
    if @skipped_plugin_count > 0
      puts "  #{@skipped_plugin_count}/#{@repolist.length} plugins are already existing"
    end
  end

  def self.show_vum_main_menu_with_prompt
    puts
    puts "  VUM (Vim bUndle Manager)"
    puts "  ========================"
    puts "  " + "#{VUM_MAIN_MENU_CHANGE_PLUGIN_INSTALL_DIR}".bold_yellow +
      ". Change plugins directory [ default: #{File.expand_path(@@plugins_dir)} ]"
    puts "  " + "#{VUM_MAIN_MENU_INSTALL_WITHOUT_CHECK}".bold_yellow +
      ". Install plugins (without checking for repositories)"
    puts "  " + "#{VUM_MAIN_MENU_INSTALL_WITH_CHECK}".bold_yellow +
      ". Install plugins after repository check"
    puts "  " + "#{VUM_MAIN_MENU_CHECK}".bold_yellow + ". Check for repositories"
    puts "  " + "#{VUM_MAIN_MENU_UPDATE}".bold_yellow + ". Update plugins"
    puts "  " + "Q".bold_yellow + ". Quit"
    puts
    show_prompt
  end

  def self.show_prompt
    print "  Choice ? "
    gets.chomp.downcase
  end

end

# update a single plugin
def update_plugin(plugin)
  dir, repo, p_n = plugin[:dir], plugin[:repo_site], plugin[:plugin_name]
  Dir.chdir(dir)
  puts "  Updating vim plugin #{p_n} from " + "#{repo}".underscore_blue + "..."
  res_out = `git pull`

  if $?.exitstatus == 0
    if res_out.include?("up-to-date")
      puts "    #{p_n} is up-to-date".bold_blue
    else
      puts "    #{p_n} updated successfully".bold_green
    end
  else
    puts "    #{p_n} updating failed".bold_red
  end
end

# main
vum = Vum.new

begin
  input = Vum.show_vum_main_menu_with_prompt
  exit if input == "q" or input == "quit"

  Dir.chdir(File.expand_path(Vum.plugins_dir))

  case input.to_i
  when Vum::VUM_MAIN_MENU_CHANGE_PLUGIN_INSTALL_DIR
    puts
    print "Enter new plugins directory : "
    new_directory = gets.chomp

    if File.directory?(new_directory)
      Vum.plugins_dir = new_directory
    else
      puts "Directory(#{new_directory}) doesn't exist"
      print "Do you want to create a new directory [y/n] ? "
      chdir_answer = gets.chomp.downcase
      if chdir_answer == 'y' or chdir_answer == 'yes'
        begin
          FileUtils.mkdir_p(new_directory)
          Vum.plugins_dir = new_directory
        rescue
          puts "Directory(#{new_directory}) creation failed"
          puts "Check if you have permissions to create the directory"
        end
      end
    end

  when Vum::VUM_MAIN_MENU_INSTALL_WITHOUT_CHECK
    puts
    puts "Install plugins without checking for repository existence"
    puts "========================================================="
    puts
    puts "Entering #{Vum.plugins_dir}"
    vum.install_plugins_without_check
    puts
    vum.print_download_summary

  when Vum::VUM_MAIN_MENU_INSTALL_WITH_CHECK
    puts
    puts "Install plugins after checking for repository existence"
    puts "======================================================="
    puts
    puts "Entering #{Vum.plugins_dir}"
    vum.install_plugins_with_check
    puts
    vum.print_download_summary

  when Vum::VUM_MAIN_MENU_CHECK
    puts
    puts "Checking for repository existence"
    puts "================================="
    vum.check_for_repo_existence

  when Vum::VUM_MAIN_MENU_UPDATE
    puts
    puts "Entering #{Vum.plugins_dir}"
    puts "Retrieving existing updatable plugin list..."
    puts
    vum.get_updatable_plugin_list
    puts "  Q".bold_yellow + ". Quit"
    puts

    while true
      print "  Enter choice : "
      choice = gets.chomp.downcase
      break if choice == 'q' or choice == 'quit'
      if choice.to_s == 'a' or choice.to_s == 'all'
        puts "  Updating all the plugins"
        # update all the plugins
        vum.existing_plugins.each do |targetted_plugin|
          update_plugin(targetted_plugin)
          puts
        end
        puts
        vum.get_updatable_plugin_list
        puts "  q".bold_yellow + ". Quit"
        puts
      elsif choice.to_i > 0 and choice.to_i < ((vum.existing_plugins.count) + 1)
        # update a specific plugin
        choice_no = choice.to_i
        targetted_plugin = vum.existing_plugins[choice_no - 1]
        update_plugin(targetted_plugin)
        # show the updatable plugin list
        puts
        vum.get_updatable_plugin_list
        puts "  q".bold_yellow + ". Quit"
        puts
      else
        puts "  Wrong choice..."
        puts
      end
    end

  else
    puts "  Wrong choice..."
  end

  vum.setup

end while true
