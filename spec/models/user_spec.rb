# == Schema Information
#
# Table name: users
#
#  id                              :integer          not null, primary key
#  email                           :string(255)      not null
#  crypted_password                :string(255)      not null
#  salt                            :string(255)      not null
#  created_at                      :datetime
#  updated_at                      :datetime
#  activation_state                :string(255)
#  activation_token                :string(255)
#  activation_token_expires_at     :datetime
#  approval_state                  :string(255)
#  reset_password_token            :string(255)
#  reset_password_token_expires_at :datetime
#  reset_password_email_sent_at    :datetime
#  last_login_at                   :datetime
#  last_logout_at                  :datetime
#  last_activity_at                :datetime
#  last_login_from_ip_address      :string(255)
#  family_name                     :string(255)      default(""), not null
#  given_name                      :string(255)      default(""), not null
#  handle_name                     :string(255)      default(""), not null
#  birthday                        :date             not null
#  email_mobile                    :string(255)
#  admin                           :boolean          default(FALSE), not null
#  class_year_id                   :integer          default(1), not null
#

require 'rails_helper'

RSpec.describe User, :type => :model do
  describe "instance methods" do
    before(:all) do
      @user = create(:admin, activate: false)
    end

    describe "activation_url" do
      it "includes activation token" do
        expect(@user.activation_url).to     include(@user.activation_token)
      end
    end

    describe "send_activation_needed_email!" do
      it "sends a mail" do
        expect(UserMailer).to receive(:email_confirmation_on_create)
                              .and_return(double("UserMailer", deliver_now: true))
                              .with(an_instance_of(User))
        @user.send_activation_needed_email!
      end
    end

    describe "send_reset_password_instructions!" do
      it "send a mail" do
        expect(UserMailer).to receive(:reset_password_instructions)
                              .and_return(double("UserMailer", deliver_now: true))
                              .with(an_instance_of(User))
        @user.send_reset_password_instructions!
      end
    end
  end

  context "registration" do
    it "automatically send welcome email" do
      user = build(:guest, activate: false)
      expect(user).to receive(:send_activation_needed_email!).once
      user.save
    end
  end
end
