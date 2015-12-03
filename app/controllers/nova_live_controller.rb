class NovaLiveController < NovaController
  include ActionController::Live
  before_action :authenticate

  api :GET,
      "nova/v2/:tenant_id/images/:image_id/file",
      "Download binary image data."
  def get_images_file
    @template = VSphereDriver::OpenstackImage.new(id: params[:image_id], connection: vsphere_connection)
    return render nothing: true, status: 404 unless @template.exist?

    response.headers["Content-Type"] = "application/octet-stream"
    Rails.logger.info("[#{params[:image_id]}] Exporting OVF")
    @template.export_ovf(output: response.stream)
    response.stream.close
    render nothing: true
  rescue ActionController::Live::ClientDisconnected
    Rails.logger.info("Stop image exporting. Client disconnected")
  end

  private

  def authenticate
    return true if @session
    session_id = request.headers["HTTP_X_AUTH_TOKEN"]
    @session   = KeystoneSession.get(session_id)
    return render json: "Failed to authenticate using provided session id", status: 403 unless @session
  end

  def vsphere_connection
    @session.connection
  end
end
