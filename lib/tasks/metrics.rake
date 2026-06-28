# frozen_string_literal: true

namespace :metrics do
  desc "Executa RubyCritic em app/ (ABC/complexidade via Flog)"
  task :rubycritic do
    sh "bundle exec rubycritic app --format html --no-browser"
  end

  desc "Executa Saikuro (complexidade ciclomática) — falha no Ruby 3.4; use metrics:cyclomatic"
  task :saikuro do
    FileUtils.mkdir_p("tmp/saikuro")
    sh "bundle exec saikuro -c -y 0 -o tmp/saikuro app"
  end

  desc "Complexidade ciclomática via RuboCop (substituto do Saikuro no Ruby 3.4)"
  task :cyclomatic do
    sh "bundle exec rubocop --only Metrics/CyclomaticComplexity app"
  end

  desc "ABC Score via RuboCop AbcSize"
  task :abc do
    sh "bundle exec rubocop --only Metrics/AbcSize app"
  end

  desc "Executa todas as métricas disponíveis"
  task all: %i[rubycritic cyclomatic abc flog] do
    puts "\nNota: bundle exec rake metrics:saikuro requer Ruby < 3.4 (CLI incompatível)."
  end
end
