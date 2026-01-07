# Custom Tailwind CSS build task that uses standalone CLI if available
namespace :css do
  desc "Build Tailwind CSS using standalone CLI"
  task build: :environment do
    input = Rails.root.join("app/assets/stylesheets/application.tailwind.css")
    output = Rails.root.join("app/assets/builds/tailwind.css")

    # Ensure builds directory exists
    FileUtils.mkdir_p(Rails.root.join("app/assets/builds"))

    # Check for standalone tailwindcss binary first
    standalone_paths = [
      "/usr/local/bin/tailwindcss",
      Rails.root.join("tailwindcss-linux-x64").to_s,
      Rails.root.join("tailwindcss-linux-arm64").to_s
    ]

    tailwindcss_bin = standalone_paths.find { |path| File.executable?(path) }

    if tailwindcss_bin
      puts "Building Tailwind CSS with standalone CLI: #{tailwindcss_bin}"
      success = system(tailwindcss_bin, "-i", input.to_s, "-o", output.to_s, "--minify")
      abort("Tailwind CSS build failed") unless success
      puts "Tailwind CSS built successfully"
    else
      # Fall back to gem-provided executable
      puts "Building Tailwind CSS with tailwindcss-rails gem"
      Rake::Task["tailwindcss:build"].invoke
    end
  end
end

# Override the default tailwindcss:build to use our custom task
Rake::Task["tailwindcss:build"].clear if Rake::Task.task_defined?("tailwindcss:build")

namespace :tailwindcss do
  desc "Build Tailwind CSS"
  task build: "css:build"
end
