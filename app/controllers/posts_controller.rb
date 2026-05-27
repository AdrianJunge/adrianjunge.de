class PostsController < ApplicationController
  def timeline
    @timeline = ContentIndex.new.timeline_groups
  end
end
