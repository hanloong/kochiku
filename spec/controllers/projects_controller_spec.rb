require 'spec_helper'
require 'rexml/document'

describe ProjectsController do
  render_views

  describe "#index" do
    let(:a) { FactoryGirl.create(:project, name: 'aster') }
    let(:b) { FactoryGirl.create(:project, name: 'buckeye') }
    let(:c) { FactoryGirl.create(:project, name: 'creosote') }

    it "shows projects in order" do
      b; a; c
      get :index
      expect(assigns(:projects).map(&:name)).to eq(%w{aster buckeye creosote})
    end
  end

  describe "#ci_projects" do
    let(:repository) { FactoryGirl.create(:repository) }
    let!(:ci_project) { FactoryGirl.create(:project, :name => repository.repository_name) }
    let!(:non_ci_project) { FactoryGirl.create(:project, :name => repository.repository_name + "-pull_requests") }

    it "only shows the ci project" do
      get :ci_projects
      expect(response).to be_success
      doc = Nokogiri::HTML(response.body)
      elements = doc.css(".projects .ci-build-info")
      expect(elements.size).to eq(1)
    end
  end

  describe "#show" do
    render_views

    let(:project) { FactoryGirl.create(:big_rails_project) }
    let!(:build1) { FactoryGirl.create(:build, :project => project, :state => :succeeded) }
    let!(:build2) { FactoryGirl.create(:build, :project => project, :state => :errored) }

    it "should return an rss feed of builds" do
      get :show, :id => project.to_param, :format => :rss
      doc = REXML::Document.new(response.body)
      items = doc.elements.to_a("//channel/item")
      expect(items.length).to eq(Build.count)
      expect(items.first.elements.to_a("title").first.text).to eq("Build Number #{build2.id} failed")
      expect(items.last.elements.to_a("title").first.text).to eq("Build Number #{build1.id} success")
    end
  end

  describe "#status_report" do
    render_views
    let(:repository) { FactoryGirl.create(:repository) }
    let(:project) { FactoryGirl.create(:project, :repository => repository, :name => repository.repository_name) }

    context "when a project has no builds" do
      before { expect(project.builds).to be_empty }

      it "should return 'Unknown' for activity" do
        get :status_report, :format => :xml
        expect(response).to be_success

        doc = Nokogiri::XML(response.body)
        element = doc.at_xpath("/Projects/Project[@name='#{project.name}']")

        expect(element['activity']).to eq('Unknown')
      end
    end

    context "with a in-progress build" do
      let!(:build) { FactoryGirl.create(:build, :state => :running, :project => project) }

      it "should return 'Building' for activity" do
        get :status_report, :format => :xml
        expect(response).to be_success

        doc = Nokogiri::XML(response.body)
        element = doc.at_xpath("/Projects/Project[@name='#{project.name}']")

        expect(element['activity']).to eq('Building')
      end
    end

    context "with a completed build" do
      let!(:build) { FactoryGirl.create(:build, :state => :failed, :project => project) }

      it "should return 'CheckingModifications' for activity" do
        get :status_report, :format => :xml
        expect(response).to be_success

        doc = Nokogiri::XML(response.body)
        element = doc.at_xpath("/Projects/Project[@name='#{project.name}']")

        expect(element['activity']).to eq('CheckingModifications')
      end
    end
  end
end
