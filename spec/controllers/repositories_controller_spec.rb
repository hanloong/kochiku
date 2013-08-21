require 'spec_helper'

describe RepositoriesController do
  render_views
  describe "post /repositories" do
    it "creates a repository" do
      expect{
        post :create, :repository => {:url => "git@git.squareup.com:square/kochiku.git", :test_command => "script/something"}
        response.should be_redirect
      }.to change(Repository, :count).by(1)
      Repository.last.url.should == "git@git.squareup.com:square/kochiku.git"
      Repository.last.test_command.should == "script/something"
    end

    it "creates a ci project" do
      expect{
        post :create, :repository => {:url => "git@git.squareup.com:square/kochiku.git", :test_command => "script/something"}
        response.should be_redirect
      }.to change(Project, :count).by(2)
      Repository.last.projects.size.should == 2
      Repository.last.projects.map(&:name).sort.should == ["kochiku", "kochiku-pull_requests"]
    end
  end

  describe "get /repositories/:id/projects" do
    let!(:repository) { FactoryGirl.create(:repository)}
    let!(:project) { FactoryGirl.create(:project, :repository => repository)}
    let!(:project2) { FactoryGirl.create(:project)}
    it "shows only a repositories projects" do
      get :projects, :id => repository.id
      response.should be_success
      doc = Nokogiri::HTML(response.body)
      elements = doc.css(".projects .build-info")
      elements.size.should == 1
    end
  end

  describe "put /repositories/:id" do
    let!(:repository) { FactoryGirl.create(:repository, :url => "git@git.squareup.com:square/kochiku.git", :test_command => "script/something")}
    it "creates a repository" do
      expect{
        put :update, :id => repository.id, :repository => {:url => "git@git.squareup.com:square/kochiku-worker.git", :test_command => "script/something-else"}
        response.should be_redirect
      }.to_not change(Repository, :count).by(1)
      Repository.last.url.should == "git@git.squareup.com:square/kochiku-worker.git"
      Repository.last.test_command.should == "script/something-else"
    end
  end

  describe "delete /repositories/:id" do
    let!(:repository) { FactoryGirl.create(:repository, :url => "git@git.squareup.com:square/kochiku.git", :test_command => "script/something")}
    it "responds with success" do
      expect {
        get :destroy, :id => repository.id
        response.should be_redirect
      }.to change(Repository, :count).by(-1)
    end
  end

  describe "get /repositories" do
    it "responds with success" do
      get :index
      response.should be_success
    end
  end

  describe "get /repositories/:id/edit" do
    it "responds with success" do
      get :edit, :id => FactoryGirl.create(:repository).id
      response.should be_success
    end
  end

  describe "get /repositories/new" do
    it "responds with success" do
      get :new
      response.should be_success
    end
  end

  describe 'post /build-ref' do
    let(:repository) { FactoryGirl.create(:repository) }

    it "creates a master build" do
      expect {
        post :build_ref, id: repository.to_param, ref: 'master', sha: 'abc123'
        response.should be_success
      }.to change(Build, :count).by(1)
      build = Build.last
      build.branch.should == "master"
      build.ref.should == "abc123"
      build.queue.should == :ci
      build.project.name.should == "kochiku"
    end

    it "creates a PR build" do
      expect {
        post :build_ref, id: repository.to_param, ref: 'blah', sha: 'abc123'
        response.should be_success
      }.to change(Build, :count).by(1)
      build = Build.last
      build.branch.should == "blah"
      build.ref.should == "abc123"
      build.queue.should == :developer
      build.project.name.should == "kochiku-pull_requests"
    end
  end
end
