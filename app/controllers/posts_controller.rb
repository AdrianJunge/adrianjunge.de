class PostsController < ApplicationController
  def timeline
    @timeline = get_mixed_timeline
  end
end
