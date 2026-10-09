# S3 vendor .ko ↔ 主线已构建 .ko 名称交叉（2026-10-09，主机侧）

> 口径：**名称精确匹配**只是初筛，不等于功能等价（主线可能 builtin 或改名）。真实映射仍需逐子系统核（S3 报告 §落地步骤1）。

- vendor_dlkm .ko：297
- 主线树已构建 .ko：1523
- 同名交集：18
- vendor-only（待逐系统映射）：279

## 同名交集（主线已构建同名模块）
```
atmel_mxt_ts coresight coresight-cti coresight-funnel coresight-replicator coresight-stm coresight-tmc goodix_ts leds-qcom-flash leds-qcom-lpg nb7vpq904m nxp-nci qcom-rng slim-qcom-ngd-ctrl slimbus smsc95xx snd-usb-audio-qmi stm_core 
```

## vendor-only 前缀分布（归一化线索）
```
     25 qcom
     15 msm
     13 qti
     10 rmnet
     10 coresight
      7 lpass
      6 stm
      6 gh
      5 usb
      5 qca
      5 phy
      4 swr
      4 hq
      4 cnss
      3 qrtr
      3 q6
      3 pinctrl
      3 mpam
      3 mhi
      3 mem
      3 debugcc
      2 wcd939x
      2 wcd938x
      2 wcd9378
      2 snd
```

## vendor-only 全量
adsp_loader_dlkm adsp_sleepmon altmode-glink audio_pkt_dlkm audio_prm_dlkm audpkt_ion_dlkm aw882xx_dlkm bam_dma bcl_soc boot_stats bt_fm_swr btfm_slim_codec btfmcodec btpower bwmon c1dcvs_scmi_v2 camera cdsprm cfg80211 charger-ulog-glink clk-scmi cnss2 cnss_nl cnss_plat_ipc_qmi_svc cnss_prealloc cnss_utils coresight-csr coresight-dummy coresight-qmi coresight-remote-etm coresight-tgu coresight-tmc-sec coresight-tpda coresight-tpdm coresight-trace-noc coresight-uetm cpu_mpam cpucp_log cpufreq_stats_scmi_v2 cpufreq_stats_scmi_v3 ddr_cdev debugcc-kera debugcc-sun debugcc-tuna dmesg_dumper drm_display_helper drm_dp_aux_bus dwc3-msm dynpf_scmi eud evacc-tuna extend_reclaim f_fs_ipc_log focaltech_fts frpc-adsprpc fsa4480-i2c fsa4480-sub-i2c gh_ctrl gh_irq_lend gh_mem_notifier gh_panic_notifier gh_rm_booster gh_tlmm_vm_mem_access glink_pkt glink_probe governor_gpubw_mon governor_msm_adreno_tz gpr_dlkm gpu_dump_skip_cdev gsim haptic hdcp_qseecom_dlkm hdmi_dlkm heap_mem_ext_v01 hq_mii hq_ptn3222_repeater hq_smsc hq_usbnet hqsysfs hung_task_enh hvc_gunyah hwmon i2c-msm-geni i3c-master-msm-geni icnss2 ipam ipanetm ipclite_test leds-qpnp-vibrator-ldo leds-qti-flash lenovo_sys_temp lenovo_thermal_control llcc_heuristics llcc_perfmon lpass_bt_swr_dlkm lpass_cdc_dlkm lpass_cdc_rx_macro_dlkm lpass_cdc_tx_macro_dlkm lpass_cdc_va_macro_dlkm lpass_cdc_wsa2_macro_dlkm lpass_cdc_wsa_macro_dlkm lt9611uxc mac80211 machine_dlkm max31760_fan mbhc_dlkm mem-hooks mem-offline mem_object memlat mhi mhi_dev_satellite mhi_dev_uci mpam mpam_msc mpam_msc_slc msm-eva msm-mmrm msm_drm msm_ext_display msm_geni_serial msm_gpi msm_hw_fence msm_kgsl msm_memshare msm_performance msm_sharedmem msm_show_epoch msm_show_resume_irq msm_sysstats msm_video nvmem_qfprom nvt_36xxx panel_event_notifier pci-msm-drv pcie-pdc pdr_interface phy-generic phy-msm-m31-eusb2 phy-msm-snps-eusb2 phy-msm-ssusb-qmp phy-qcom-emu pinctrl-spmi-gpio pinctrl-spmi-mpp pinctrl_lpi_dlkm platform_mpam pm8941-pwrkey pmic-glink-debug q2spi-geni q6_dlkm q6_notifier_dlkm q6_pdr_dlkm qca_cld3_kiwi_v2 qca_cld3_peach qca_cld3_peach_v2 qca_cld3_qca6750 qca_cld3_wcn7750 qce50_dlkm qcedev-mod_dlkm qcom-amoled-regulator qcom-cpufreq-hw-debug qcom-i2c-pmic qcom-pon qcom-spmi-adc5-gen3 qcom-spmi-temp-alarm qcom-vadc-common qcom_cpuss_sleep_stats qcom_cpuss_sleep_stats_v4 qcom_dynamic_ramoops qcom_edac qcom_glink qcom_glink_smem qcom_glink_spss qcom_iommu_debug qcom_lpm qcom_pil_info qcom_q6v5 qcom_q6v5_pas qcom_ramdump qcom_smd qcom_spss qcom_stats qcom_sysmon qcom_va_minidump qcrypto-msm_dlkm qfprom-sys qmi_helpers qmp_dlkm qrng_dlkm qrtr-mhi qrtr-smd qrtr-tun qsee_ipc_irq_bridge qseecom_proxy qti-fixed-regulator qti-glink-adc qti-ocp-notifier qti_amoled_ecm qti_battery_charger qti_battery_debug qti_cpufreq_cdev qti_devfreq_cdev qti_dmof_scmi qti_pmic_glink qti_qmi_cdev qti_qmi_sensor_v2 qti_userspace_cdev qts radio-i2c-rtc6226-qca rdbg reboot-mode redriver repeater repeater-qti-pmic-eusb2 rmnet_aps rmnet_core rmnet_ctl rmnet_mem rmnet_offload rmnet_perf rmnet_perf_tether rmnet_sch rmnet_shs rmnet_wlan rproc_qcom_common si_core_module slc_mpam smcinvoke_dlkm smem-mailbox smmu_proxy_dlkm smp2p smp2p_sleepstate snd-soc-hdmi-codec snd_event_dlkm spcom spf_core_dlkm spi-msm-geni spmi-pmic-arb-debug sps_drv spss_utils st_fts stm_console stm_ftrace stm_heartbeat stm_nfc_i2c stm_p_ost stm_st54se_gpio stub_dlkm swr_ctrl_dlkm swr_dlkm swr_dmic_dlkm swr_haptics_dlkm sync_fence synx-driver sys_pm_vx sysmon_subsystem_stats thermal_config tmecom-intf tz_log_dlkm ucsi_qti_glink ufsffu usb_f_ccid usb_f_cdev usb_f_gsi usb_f_qdss usb_f_rndis videocc-tuna wcd9378_dlkm wcd9378_slave_dlkm wcd938x_dlkm wcd938x_slave_dlkm wcd939x_dlkm wcd939x_slave_dlkm wcd9xxx_dlkm wcd_core_dlkm wlan_firmware_service wsa883x_dlkm wsa884x_dlkm xhci-sideband 
