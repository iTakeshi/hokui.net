class UserSerializer < ActiveModel::Serializer
  attributes :id,
             :email,
             :activation_state,
             :approval_state,
             :last_login_at,
             :last_logout_at,
             :last_activity_at,
             :last_login_from_ip_address,
             :family_name,
             :given_name,
             :full_name,
             :handle_name,
             :birthday,
             :email_mobile,
             :admin,
             :class_year_id,
             :errors

  def full_name
    object.full_name
  end

  def errors
    object.errors
  end
end
