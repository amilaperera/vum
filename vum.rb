#!/usr/bin/env ruby

# VUM - Vim plUgin Manager
# This downloads/updates/deletes vim plugins that are managed via git

require 'rubygems'
require 'colorize'

class Vum
  VUM_REPOS_FILE = ENV["HOME"] + "/.vum_repos"
  VUM_MAIN_MENU_INSTALL_WITHOUT_CHECK = 1
  VUM_MAIN_MENU_INSTALL_WITH_CHECK = 2
  VUM_MAIN_MENU_CHECK = 3

  attr_reader :repolist, :ok_repolist, :failed_repolist, :download_ok_count, :download_failed_count

  def initialize
    @repolist = get_repolist_from_file # if success repolist hash is sorted by plugin name
    @ok_repolist = []
    @failed_repolist = []
    @download_ok_count = 0
    @download_failed_count = 0
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
    puts "#{@ok_repolist.length}/#{@repolist.length}" +
          " repositories seem to be good enough for downloading" if @ok_repolist.length > 0

    puts "#{@failed_repolist.length}/#{@repolist.length}" +
          " repositories were found to have some troubles" +
          " and vum will not use those repositories for downloading" if @failed_repolist.length > 0

    print "Proceed [y/n] ? "
    answer = gets.chomp
    return unless answer.downcase == "y" || answer.downcase == "yes"

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
      padding_length = max_repo_plugin_site_name_length + 4 - repo[:repo_site].length - repo[:plugin_name].length

      `git ls-remote #{repo[:repo_site]} 2>/dev/null 1>&2`
      if $?.exitstatus == 0
        @ok_repolist << repo
        puts "#{repo[:plugin_name]}".bold.green + "(#{repo[:repo_site]}) " +
            ("." * padding_length) + " [   "+ "OK".bold.green + "   ]"
      else
        @failed_repolist << repo
        puts "#{repo[:plugin_name]}".bold.red + "(#{repo[:repo_site]}) " +
            ("." * padding_length) + " [ "+ "FAILED".bold.red + " ]"
      end
    end
  end

  def download_plugins
    puts
    puts "Plugins download starts"
    puts

    max_repo_plugin_site_name_length = get_max_repo_line_length(@ok_repolist)

    @ok_repolist.each_with_index do |repo, index|

      padding_length = max_repo_plugin_site_name_length - (index + 1).to_s.length + 4 - repo[:repo_site].length - repo[:plugin_name].length

      `git clone #{repo[:repo_site]} 2>/dev/null 1>&2`
      if $?.exitstatus == 0
        print "(#{index + 1}/#{@ok_repolist.length}) Downloading " + "#{repo[:plugin_name]}".bold.green +
          " from #{repo[:repo_site]} " + "." * padding_length
        puts " [   " + "OK".bold.green + "   ]"
        @download_ok_count += 1
      else
        print "(#{index + 1}/#{@ok_repolist.length}) Downloading " + "#{repo[:plugin_name]}".bold.red +
          " from #{repo[:repo_site]} " + "." * padding_length
        puts " [ " + "FAILED".bold.red + " ]"
        @download_failed_count += 1
      end
    end
  end

  def get_plugin_name(line)
    line.gsub(/.*\//, "").gsub(/\..*$/, "").capitalize
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

  def self.show_vum_main_menu_with_prompt
    puts
    puts "  VUM (Vim bUndle Manager)"
    puts "  ========================"
    puts
    puts "  " + "#{VUM_MAIN_MENU_INSTALL_WITHOUT_CHECK}" + ". Install plugins (without checking for repositories)"
    puts "  " + "#{VUM_MAIN_MENU_INSTALL_WITH_CHECK}" + ". Install plugins after repository check"
    puts "  " + "#{VUM_MAIN_MENU_CHECK}" + ". Check for repositories"
    puts "  " + "q" + ". Quit"
    puts
    print "  Choice ? "
    gets.chomp
  end

  def self.show_prompt
    print "  Choice ? "
    gets.chomp
  end

end

# main
input = Vum.show_vum_main_menu_with_prompt

vum = Vum.new

begin
  is_good_choice = true
  exit if input == "q" || input == "Q"

  case input.to_i
  when Vum::VUM_MAIN_MENU_INSTALL_WITHOUT_CHECK
    puts
    puts "Install plugins without checking for repository existence"
    puts "========================================================="
    vum.install_plugins_without_check
    puts
    puts "  #{vum.download_ok_count}/#{vum.repolist.length} plugins were downloaded successfully" if vum.download_ok_count > 0
    puts "  #{vum.download_failed_count}/#{vum.repolist.length} plugins failed during downloading for some reason" if vum.download_failed_count > 0
    puts

  when Vum::VUM_MAIN_MENU_INSTALL_WITH_CHECK
    puts
    puts "Install plugins after checking for repository existence"
    puts "======================================================="
    vum.install_plugins_with_check
    puts
    puts "  #{vum.download_ok_count}/#{vum.repolist.length} plugins were downloaded successfully" if vum.download_ok_count > 0
    puts "  #{vum.download_failed_count}/#{vum.repolist.length} plugins failed during downloading for some reason" if vum.download_failed_count > 0
    puts

  when Vum::VUM_MAIN_MENU_CHECK
    puts
    puts "Checking for repository existence"
    puts "================================="
    vum.check_for_repo_existence

  else
    is_good_choice = false

    puts "  Wrong choice..."
    input = Vum.show_prompt
  end
end while not is_good_choice
