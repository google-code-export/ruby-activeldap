# -*- ruby -*-

desc "Update *.po/*.pot files and create *.mo from *.po files"
task :gettext => ["gettext:po:update", "gettext:mo:create"]

namespace :gettext do
  namespace :environment do
    desc "Setup environment for GetText"
    task :setup => :environment do
      require "gettext/utils"
    end
  end

  namespace :po do
    desc "Update po/pot files (GetText)"
    task :update => "gettext:environment:setup" do
      GetText.update_pofiles("al-admin",
                             Dir.glob("{app,lib}/**/*.rb") +
                             Dir.glob("app/views/**/*.rhtml"),
                             "AL Admin #{AL_ADMIN_VERSION}")
    end
  end

  namespace :mo do
    desc "Create *.mo from *.po (GetText)"
    task :create => "gettext:environment:setup" do
      GetText.create_mofiles(false, 'po', 'locale')
    end
  end
end
