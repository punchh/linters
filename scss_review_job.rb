require "resque"
require "scss_lint"

require_relative "review_job"
require_relative "config_options"

class ScssReviewJob
  @queue = :scss_review

  def self.perform(attributes)
    # repo_name
    # filename
    # commit_sha
    # patch
    # content
    # config

    config_options = ConfigOptions.new(attributes["config"])
    scss_lint_config = SCSSLint::Config.new(config_options.to_hash)
    filename = attributes.fetch("filename")
    violations = []

    unless scss_lint_config.excluded_file?(filename)
      scss_lint_runner = SCSSLint::Runner.new(scss_lint_config)
      scss_lint_runner.run([attributes["content"]])

      violations = scss_lint_runner.lints.map do |lint|
        { line: lint.location.line, message: lint.description }
      end
    end

    Resque.enqueue(
      ReviewJob,
      repo_name: attributes.fetch("repo_name"),
      filename: filename,
      commit_sha: attributes.fetch("commit_sha"),
      patch: attributes.fetch("patch"),
      violations: violations
    )
  end
end