# Filters added to this controller will be run for all controllers in the application.
# Likewise, all the methods added will be available for all controllers.
class ApplicationController < ActionController::Base
  cattr_accessor :site_count
  before_filter  :set_cache_root
  helper_method  :site
  attr_reader    :site

  protected
    [:utc_to_local, :local_to_utc].each do |meth|
      define_method meth do |time|
        site.timezone.send(meth, time)
      end
      helper_method meth
    end

    def render_liquid_template_for(template_type, assigns = {})
      headers["Content-Type"] ||= 'text/html; charset=utf-8'
    
      if assigns['articles'] && assigns['article'].nil?
        self.cached_references += assigns['articles']
        assigns['articles']     = assigns['articles'].collect &:to_liquid
      end

      status          = (assigns.delete(:status) || '200 OK')
      @liquid_assigns = assigns
      render :text => site.templates.render_liquid_for(site, @section, template_type, assigns, self), :status => status
    end

    def show_error(message = 'An error occurred.', status = '500 Error')
      render_liquid_template_for(:error, 'message' => message, :status => status)
    end

    def show_404
      show_error 'Page Not Found', '404 NotFound'
    end

    def set_cache_root
      @site ||= Site.find_by_host(request.host) || Site.find(:first, :order => 'id')
      # prepping for site-specific page cache directories, DONT PANIC
      #self.class.page_cache_directory = File.join([RAILS_ROOT, (RAILS_ENV == 'test' ? 'tmp' : 'public'), 'sites', site.host])
    end

    def with_site_timezone
      old_tz = ENV['TZ']
      ENV['TZ'] = site.timezone.name
      yield
      ENV['TZ'] = old_tz
    end
    
    def rescue_action_in_public(exception)
      case exception
        when ActiveRecord::RecordNotFound, ActionController::UnknownController, ActionController::UnknownAction
          render :file => File.join(RAILS_ROOT, 'public/404.html'), :status => '404 Not Found'
        else
          render :file => File.join(RAILS_ROOT, 'public/500.html'), :status => '500 Error'
      end
    end
end