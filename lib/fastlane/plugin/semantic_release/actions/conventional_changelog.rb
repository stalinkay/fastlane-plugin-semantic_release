require 'fastlane/action'
require_relative '../helper/semantic_release_helper'

module Fastlane
  module Actions
    module SharedValues
    end

    class ConventionalChangelogAction < Action
      def self.run(params)
        # Get next version number from shared values
        analyzed = lane_context[SharedValues::RELEASE_ANALYZED]

        # If analyze commits action was not run there will be no version in shared
        # values. We need to run the action to get next version number
        unless analyzed
          UI.user_error!("Release hasn't been analyzed yet. Run analyze_commits action first please.")
          # version = other_action.analyze_commits(match: params[:match])
        end

        last_tag_hash = lane_context[SharedValues::RELEASE_LAST_TAG_HASH]
        version = lane_context[SharedValues::RELEASE_NEXT_VERSION]

        # Get commits log between last version and head
        commits = Helper::SemanticReleaseHelper.git_log('%s|%H|%h|%an|%at', last_tag_hash)
        parsed = parse_commits(commits.split("\n"))

        commit_url = params[:commit_url]

        if params[:format] == 'markdown'
          result = markdown(parsed, version, commit_url, params)
        elsif params[:format] == 'slack'
          result = slack(parsed, version, commit_url, params)
        end

        result
      end

      def self.markdown(commits, version, commit_url, params)
        sections = params[:sections]

        title = version
        title += " #{params[:title]}" if params[:title]

        # Begining of release notes
        result = "##{title} (#{Date.today})"
        result += "\n"

        params[:order].each do |type|
          # write section only if there is at least one commit
          next if commits.none? { |commit| commit[:type] == type }

          result += "\n\n"
          result += "### #{sections[type.to_sym]}"
          result += "\n"

          commits.each do |commit|
            next if commit[:type] != type

            author_name = commit[:author_name]
            short_hash = commit[:short_hash]
            hash = commit[:hash]
            link = "#{commit_url}/#{hash}"

            result += "- #{commit[:subject]} ([#{short_hash}](#{link}))"

            if params[:display_author]
              result += "- #{author_name}"
            end

            result += "\n"
          end
        end

        result
      end

      def self.slack(commits, version, commit_url, params)
        sections = params[:sections]

        # Begining of release notes
        result = "*#{version} #{params[:title]}* (#{Date.today})"
        result += "\n"

        params[:order].each do |type|
          # write section only if there is at least one commit
          next if commits.none? { |commit| commit[:type] == type }

          result += "\n\n"
          result += "*#{sections[type.to_sym]}*"
          result += "\n"

          commits.each do |commit|
            next if commit[:type] != type

            author_name = commit[:author_name]
            short_hash = commit[:short_hash]
            hash = commit[:hash]
            link = "#{commit_url}/#{hash}"

            result += "- #{commit[:subject]} (<#{link}|#{short_hash}>)"

            if params[:display_author]
              result += "- #{author_name}"
            end

            result += "\n"
          end
        end

        result
      end

      def self.parse_commits(commits)
        parsed = []
        # %s|%H|%h|%an|%at
        commits.each do |line|
          splitted = line.split("|")

          subject_splitted = splitted[0].split(":")

          if subject_splitted.length > 1
            type = subject_splitted[0]
            subject = subject_splitted[1]
          else
            type = 'no_type'
            subject = subject_splitted[0]
          end

          commit = {
            type: type.strip,
            subject: subject.strip,
            hash: splitted[1],
            short_hash: splitted[2],
            author_name: splitted[3],
            commitDate: splitted[4]
          }

          parsed.push(commit)
        end

        parsed
      end

      #####################################################
      # @!group Documentation
      #####################################################

      def self.description
        "Get commits since last version and generates release notes"
      end

      def self.details
        "Uses conventional commits. It groups commits by their types and generates release notes in markdown or slack format."
      end

      def self.available_options
        # Define all options your action supports.

        # Below a few examples
        [
          FastlaneCore::ConfigItem.new(
            key: :format,
            description: "You can use either markdown or slack",
            default_value: "markdown",
            optional: true
          ),
          FastlaneCore::ConfigItem.new(
            key: :title,
            description: "Title of release notes",
            optional: true
          ),
          FastlaneCore::ConfigItem.new(
            key: :commit_url,
            description: "Uses as a link to the commit",
            optional: true
          ),
          FastlaneCore::ConfigItem.new(
            key: :order,
            description: "You can change order of groups in release notes",
            default_value: ["feat", "fix", "refactor", "perf", "chore", "test", "docs", "no_type"],
            type: Array,
            optional: true
          ),
          FastlaneCore::ConfigItem.new(
            key: :sections,
            description: "Map type to section title",
            default_value: {
              feat: "Features",
              fix: "Bug fixes",
              refactor: "Code refactoring",
              perf: "Performance improving",
              chore: "Building system",
              test: "Testing",
              docs: "Documentation",
              no_type: "Rest work"
            },
            type: Hash,
            optional: true
          ),
          FastlaneCore::ConfigItem.new(
            key: :display_author,
            description: "Wheter or not you want to display author of commit",
            default_value: false,
            type: Boolean,
            optional: true
          )
        ]
      end

      def self.output
        # Define the shared values you are going to provide
        # Example
        []
      end

      def self.return_value
        # If your method provides a return value, you can describe here what it does
        "Returns generated release notes as a string"
      end

      def self.authors
        # So no one will ever forget your contribution to fastlane :) You are awesome btw!
        ["xotahal"]
      end

      def self.is_supported?(platform)
        # you can do things like
        true
      end
    end
  end
end
