import Config
import Dotenvy

env_dir_prefix = System.get_env("RELEASE_ROOT") || Path.expand("./envs")

source!([
  Path.absname(".env", env_dir_prefix),
  Path.absname(".overrides.env", env_dir_prefix),
  Path.absname("#{config_env()}.env", env_dir_prefix),
  Path.absname("#{config_env()}.overrides.env", env_dir_prefix),
  System.get_env()
])

config :pi_flex,
  board_type: env!("BOARD_TYPE", :string),
  eth0_iface: env!("ETH0_IFACE", :string),
  eth0_port: env!("ETH0_PORT", :integer),
  cloud_host: env!("CLOUD_HOST", :string),
  cloud_port: env!("CLOUD_PORT", :integer),
  cloud_slave: env!("CLOUD_SLAVE", :integer),
  cloud_id: env!("CLOUD_ID", :string),
  cloud_id_register: env!("CLOUD_ID_REGISTER", :integer),
  cloud_token: env!("CLOUD_TOKEN", :string),
  cloud_token_register: env!("CLOUD_TOKEN_REGISTER", :integer),
  panel_year_register: env!("PANEL_YEAR_REGISTER", :integer),
  panel_month_register: env!("PANEL_MONTH_REGISTER", :integer),
  panel_day_register: env!("PANEL_DAY_REGISTER", :integer),
  panel_hour_register: env!("PANEL_HOUR_REGISTER", :integer),
  panel_min_register: env!("PANEL_MIN_REGISTER", :integer),
  panel_sec_register: env!("PANEL_SEC_REGISTER", :integer),
  panel_mil_register: env!("PANEL_MIL_REGISTER", :integer),
  i1_register: env!("I1_REGISTER", :integer),
  i2_register: env!("I2_REGISTER", :integer),
  i3_register: env!("I3_REGISTER", :integer),
  fan_register: env!("FAN_REGISTER", :integer),
  max_data_files: env!("MAX_DATA_FILES", :integer),
  cloud_on_register: env!("CLOUD_ON_REGISTER", :integer),
  panel_ip_register: env!("PANEL_IP_REGISTER", :integer),
  wifi_error_register: env!("WIFI_ERROR_REGISTER", :integer),
  wifi_ip_register: env!("WIFI_IP_REGISTER", :integer),
  wifi_ssid1_register: env!("WIFI_SSID1_REGISTER", :integer),
  wifi_ssid2_register: env!("WIFI_SSID2_REGISTER", :integer),
  wifi_ssid3_register: env!("WIFI_SSID3_REGISTER", :integer),
  wifi_ssid4_register: env!("WIFI_SSID4_REGISTER", :integer),
  wifi_ssid5_register: env!("WIFI_SSID5_REGISTER", :integer),
  wifi_ssid6_register: env!("WIFI_SSID6_REGISTER", :integer),
  wifi_ssid7_register: env!("WIFI_SSID7_REGISTER", :integer),
  wifi_ssid8_register: env!("WIFI_SSID8_REGISTER", :integer),
  gpio_stop_pin: env!("GPIO_STOP_PIN", :integer),
  gpio_stop_register: env!("GPIO_STOP_REGISTER", :integer),
  gpio_stop_on: env!("GPIO_STOP_ON", :integer),
  gpio_fan_pin: env!("GPIO_FAN_PIN", :integer),
  gpio_fan_register: env!("GPIO_FAN_REGISTER", :integer),
  ftp_port: env!("FTP_PORT", :integer),
  ftp_folder: env!("FTP_FOLDER", :string),
  ftp_user: env!("FTP_USER", :string),
  ftp_password: env!("FTP_PASSWORD", :string),
  proxy_iface: env!("PROXY_IFACE", :string),
  proxy_panel_port: env!("PROXY_PANEL_PORT", :integer),
  proxy_pi_port: env!("PROXY_PI_PORT", :integer)

ftp_dir =
  to_charlist(Path.join(System.get_env("HOME"), "data/pi_flex.log"))

config :logger, :default_formatter, format: "$date $time [$level] $message\n"

config :logger, :default_handler,
  config: [
    file: ftp_dir,
    filesync_repeat_interval: 5000,
    file_check: 5000,
    max_no_bytes: 1_000_000,
    max_no_files: 5,
    compress_on_rotate: true
  ]
