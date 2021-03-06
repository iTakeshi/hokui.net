class Contents::DocumentFilesController < Contents::ApplicationController
  def show
    begin
      @document_file = DocumentFile.find(params[:id])
    rescue
      # TODO
      render text: "File not found", status: 404
      return
    end

    if authorize_download
      filepath = @document_file.file_fullpath
      filename = ERB::Util.url_encode(@document_file.file_name)
      filesize = File.stat(filepath).size
      send_file(filepath, filename: filename, length: filesize)
    else
      # TODO
      render text: "Download not authorized", status: 401
    end
  end

  private

  def authorize_download
    download_token = DownloadToken.find_token(params[:download_token])
    if download_token && download_token.document_file_id == @document_file.id
      download_token.destroy!
      true
    else
      false
    end
  end
end
