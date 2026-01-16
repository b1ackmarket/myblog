+++
title = 'u30air充当hugo博客服务器'
date = '2026-01-15T21:22:06+08:00'
lastmod = '2026-01-15T21:22:06+08:00'
draft = false
tags = ["u30air"]
categories = ["技术"]

+++

插件商店有一个cloudflare tunnel的插件，但使用时总是无法连接到tunnel，怀疑是gfw阻拦，故重新写了一版代码，能配合mihomo插件走代理通道实现连接cftunnel。

下面是基于插件商店的mihomo插件（原名猫猫插件3.0，现已下架，原作者也许是minikano即ufitools作者）。默认tun端口是7890，无需改动，后面cloudflare tunnel还要用到这个端口。把mihomo插件配置好之后，确认能翻过gfw了，再进行后续操作。

```javascript
//<script>
(() => {
    const checkAdvanceFunc = async () => {
        const res = await runShellWithRoot('whoami')
        if (res.content) {
            if (res.content.includes('root')) {
                return true
            }
        }
        return false
    }

    //创建随机数
    const createRandomString = (length = 8) => {
        const characters = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789';
        let result = '';
        for (let i = 0; i < length; i++) {
            result += characters.charAt(Math.floor(Math.random() * characters.length));
        }
        return result;
    }

    const isMMRunning = async () => {
        const status = await runShellWithRoot('pgrep Clash')
        const running_mm = document.querySelector('#running_mm')
        const isR = status.content != null && status.content != undefined && status.content != ''
        if (running_mm) {
            running_mm.innerHTML = isR ? "猫猫 - 🟢运行中" : "猫猫 - 🔴已停止"
        }
        return isR
    }

    async function isELF(file) {
        const blob = file.slice(0, 4); // 前4字节
        const buffer = await blob.arrayBuffer();
        const bytes = new Uint8Array(buffer);

        return bytes[0] === 0x7F &&
            bytes[1] === 0x45 &&
            bytes[2] === 0x4C &&
            bytes[3] === 0x46;
    }


    // 检测是否开机自启
    const checkIsBootUp = async () => {
        const res = await runShellWithRoot(`
        grep -q '/data/clash/Scripts/Clash.Service start' /sdcard/ufi_tools_boot.sh
        echo $?
        `)
        return res.content.trim() == '0';
    }

    //监测是否已经安装过了
    const checkIsInstalled = async () => {
        const res = await runShellWithRoot(`
        ls /data/clash/Scripts/Clash.Service
        `)
        return res.success && res.content && res.content.includes('Clash.Service');
    }

    const saveConfig = async (file) => {
        try {
            const formData = new FormData();
            formData.append("file", file);
            const res = await (await fetch(`${KANO_baseURL}/upload_img`, {
                method: "POST",
                headers: common_headers,
                body: formData,
            })).json()

            if (res.url) {
                let foundFile = await runShellWithRoot(`
                        ls /data/data/com.minikano.f50_sms/files/${res.url}
                    `)
                if (!foundFile.content) {
                    throw "上传失败"
                }
                let resShell = await runShellWithRoot(`
                        mv  /data/data/com.minikano.f50_sms/files/${res.url} /data/clash/Proxy/config.yaml
                    `)
                if (resShell.success) {
                    createToast(`上传成功！正在重启核心...`, 'green')
                    btn_restart.click()
                    return true
                }
            }
            else throw res.error || ''
        }
        catch (e) {
            console.error(e);
            createToast(`上传失败!`, 'red')
            return false
        }
    }


    const showDialog = (message, title = "提示") => {
        let timer = null
        const containerId = "toast_" + createRandomString(4)
        const id = 'close_message_btn_' + createRandomString(4)
        const id_download = 'download_btn_' + createRandomString(4)
        const id_clear = 'clear_btn_' + createRandomString(4)
        const id_refresh = 'clear_btn_' + createRandomString(4)
        const message1 = message.replaceAll('\n', "<br>")
        const { el, close } = createFixedToast(containerId, `
        <div style="pointer-events:all;width:80vw;max-width:800px">
            <div class="title" style="margin:0" data-i18n="system_notice">${title}</div>
            <div class="content_message" style="margin:10px 0;max-height: 400px;overflow: auto;font-size: .64rem;">${message1}</div>
            <div style="text-align:right">
                <button style="font-size:.64rem" id="${id}" data-i18n="close_btn">${t('close_btn')}</button>
                <button style="font-size:.64rem" id="${id_download}" data-i18n="only_download">${t('only_download')}</button>
                <button style="font-size:.64rem" id="${id_refresh}">刷新</button>
                <button style="font-size:.64rem" id="${id_clear}">清空日志</button>
            </div>
        </div>
        `)
        const btn = el.querySelector(`#${id}`)
        const download = el.querySelector(`#${id_download}`)
        const clearBtn = el.querySelector(`#${id_clear}`)
        const rBtn = el.querySelector(`#${id_refresh}`)
        if (!btn) {
            close()
            return
        }
        if (download) {
            download.onclick = async () => {
                const t = Math.floor(Date.now() + Math.random())
                const file = new File([message1.replaceAll("<br>", "\n")], { type: 'text/plain' });
                const url = URL.createObjectURL(file);
                const a = document.createElement('a');
                a.download = `kano_mm_log_${t}.txt`;
                a.href = url;
                document.body.appendChild(a)
                a.click();
                URL.revokeObjectURL(url);
                a.remove()
            }
        }

        if (clearBtn) {
            clearBtn.onclick = async () => {
                const res = await runShellWithRoot(`echo "" > /sdcard/Clash内核日志.txt`)
                if (res.success) {
                    createToast("日志已清空", 'green')
                    close()
                } else {
                    createToast(`清空日志失败`, 'red')
                }
            }
        }

        const refresh = async (flag = false) => {
            const msg_el = el.querySelector(`.content_message`)
            const res = await runShellWithRoot(`timeout 2s awk '{print}' /sdcard/Clash内核日志.txt`)
            if (res.success) {
                msg_el.innerHTML = res.content.replaceAll('\n', "<br>")
                flag && createToast("日志已刷新")
            } else {
                flag && createToast("获取日志失败", 'red')
            }
        }

        if (rBtn) {
            rBtn.onclick = async () => {
                await refresh(true)
            }
        }

        if (timer) clearInterval(timer)
        timer = setInterval(async () => { await refresh() }, 1000)

        btn.onclick = async () => {
            if (timer) clearInterval(timer)
            close()
        }
    }

    const btn_enabled = document.createElement('button')
    btn_enabled.textContent = "安装"
    let disabled_btn_enabled = false
    btn_enabled.onclick = async (e) => {
        if (disabled_btn_enabled) return
        disabled_btn_enabled = true
        try {
            if (!(await checkAdvanceFunc())) {
                disabled_btn_enabled = false
                createToast("没有开启高级功能，无法使用！", 'red')
                return
            }
            if (await checkIsInstalled()) {
                disabled_btn_enabled = false
                createToast("已经安装过猫猫了！", 'red')
                return
            }

            createToast("下载所需组件中...")
            const res0 = await runShellWithRoot(`/data/data/com.minikano.f50_sms/files/curl -L "https://pan.kanokano.cn/d/UFI-TOOLS-UPDATE/plugins/mihomo.zip" -o /data/kano_clash.zip --output /data/kano_clash.zip --write-out "DOWNLOAD_DONE\nTotal: %{size_download} bytes\nSpeed: %{speed_download} B/s\nTime: %{time_total} sec\n" > /data/kano_mihomo_latest.dlog 2>&1 &`, 100 * 1000)
            if (!res0.success) {
                btn_enabled.disabled = false;
                return createToast("下载依赖失败!", 'red')
            }

            let log = ''
            const max_times = 600 // 最多等待10分钟
            let count_times = 0
            const { el, close } = createFixedToast("kano_mihomo_toast", `<pre style="white-space: pre-wrap;min-width:300px;text-align: center;">等待日志中...</pre>`, '')

            const interval = setInterval(async () => {
                const dlog = await runShellWithRoot("timeout 2s  awk '{print}' /data/kano_mihomo_latest.dlog")
                const lines = dlog.content.split('\n'); // 按换行符拆分成数组
                log = lines.slice(-6).join('\n');
                el.innerHTML = `<pre style="white-space: pre-wrap;min-width:300px;text-align: center;">${log.replaceAll('\n', "<br>")}</pre>`
                if (log.includes('DOWNLOAD_DONE')) {
                    setTimeout(() => {
                        close()
                    }, 2000);
                }
            }, 1000)

            while (true) {
                if (max_times <= count_times) {
                    clearInterval(interval)
                    btn_enabled.disabled = false;
                    return ("下载超时，请检查网络连接或稍后重试！", 'red')
                }
                if (log.includes('DOWNLOAD_DONE')) {
                    clearInterval(interval)
                    break
                }
                count_times++
                await new Promise(resolve => setTimeout(resolve, 1000))
            }

            await runShellWithRoot("rm -f /data/kano_mihomo_latest.dlog")

            createToast("解压猫猫文件...")
            const res2 = await runShellWithRoot(`
        cd /data/
        mkdir -p clash
        unzip kano_clash.zip -d /data/clash/
        `)
            if (!res2.success) return createToast("解压猫猫文件出错!", 'red')

            createToast("检查依赖文件，可能需要一点时间...")
            const res3 = await runShellWithRoot(`
        ls /data/clash/Scripts
        `)
            if (!res3.success || !res3.content.includes('Clash.Service')) return createToast("检查猫猫依赖文件失败!", 'red')

            createToast("正在安装猫猫，设置Clash自启动...")
            const res5 = await runShellWithRoot(`
cp /data/clash/Proxy/config.yaml /data/data/com.minikano.f50_sms/files/uploads/default_mm.yaml
cp /data/clash/Proxy/config.yaml /sdcard/默认猫猫配置_config.yaml
chmod 777 -Rf /data/clash
grep -qxF '/data/clash/Scripts/Clash.Service start' /sdcard/ufi_tools_boot.sh || echo '/data/clash/Scripts/Clash.Service start' >> /sdcard/ufi_tools_boot.sh
grep -qxF 'inotifyd /data/clash/Scripts/Clash.Inotify "/data/clash/Clash" >> /dev/null &' /sdcard/ufi_tools_boot.sh || echo 'inotifyd /data/clash/Scripts/Clash.Inotify "/data/clash/Clash" >> /dev/null &' >> /sdcard/ufi_tools_boot.sh
        `)
            if (!res5.success) return createToast("设置猫猫自启动失败!", 'red')

            createToast("启动Clash...")
            const res6 = await runShellWithRoot(`
        /data/clash/Scripts/Clash.Service start
        `)
            if (!res6.success) return createToast("启动猫猫失败!", 'red')

            createToast(`<div style="width:300px;text-align:center;pointer-events: all;">
                启动Clash成功！<br />
                web地址(端口默认是7788)<br />
                <a href="http://192.168.0.1:7788/ui/" target="_blank">http://192.168.0.1:7788/ui/</a><br />
                token密码默认为123456<br />
                可以在/sdcard/默认猫猫配置_config.yaml中获取默认配置<br/>
                也可导出默认配置，然后修改好上传配置<br />
                依赖文件路径:/data/clash/<br/>
                内核日志:sdcard/Clash内核日志.txt<br/>
                输出:${res6.content}
        </div>
        `, '', 20000)

            disabled_btn_enabled = false

            checkIsBootUp().then(isBootUp => {
                const boot_on = document.querySelector('#clash_boot_on')
                if (!boot_on) return
                if (isBootUp) {
                    boot_on.style.background = "var(--dark-btn-color-active)"
                } else {
                    boot_on.style.background = ""
                }
            })
            setTimeout(() => {
                isMMRunning()
            }, 3000);
        } finally {
            disabled_btn_enabled = false
            await runShellWithRoot(`rm -f /data/kano_clash.zip`)
        }
    }
    const btn_disabled = document.createElement('button')
    btn_disabled.textContent = "卸载"
    let ct = 0
    let tmer = null
    btn_disabled.onclick = async () => {
        if (!(await checkAdvanceFunc())) {
            createToast("没有开启高级功能，无法使用！", 'red')
            return
        }
        ct++
        tmer && clearTimeout(tmer)
        tmer = setTimeout(() => {
            ct = 0
        }, 3000);
        if (ct < 3) { return createToast("再点一次卸载猫猫") }
        createToast("卸载中...", 'red')
        const res = await runShellWithRoot(`
        /data/clash/Scripts/Clash.Service stop
        sleep 1
        rm -rf /data/clash
        sed -i '/Clash.Service/d' /sdcard/ufi_tools_boot.sh
        sed -i '/Clash.Inotify/d' /sdcard/ufi_tools_boot.sh
        `)
        if (!res.success) return createToast("卸载失败！", 'red')
        createToast(`<div style="width:300px;text-align:center">
        卸载结果：${res.content}<br/>
        如果没有错误即视为卸载成功
        </div>`)
        await isMMRunning()
    }

    const btn_restart = document.createElement('button')
    btn_restart.textContent = "重启"
    btn_restart.onclick = async () => {
        if (!(await checkAdvanceFunc())) {
            createToast("没有开启高级功能，无法使用！", 'red')
            return
        }
        if (!await checkIsInstalled()) {
            createToast("没有安装猫猫，请先安装！", 'red')
            return
        }
        createToast("重启猫猫中...", 'green')
        const res = await runShellWithRoot(`
        /data/clash/Scripts/Clash.Service stop
        sleep 1
        /data/clash/Scripts/Clash.Service start
        `)
        if (!res.success) return createToast("重启失败！", 'red')
        createToast(`<div style="width:300px;text-align:center">
            ${res.content.replaceAll('\n', "<br/>")}
        </div>`, 'green')
        await isMMRunning()
    }

    //一键上传
    const uploadEl = document.createElement('input')
    uploadEl.type = 'file'
    uploadEl.onchange = async (e) => {
        if (!e?.target?.files) return
        const file = e.target.files[0];
        if (file) {
            if (!(await checkAdvanceFunc())) {
                createToast("没有开启高级功能，无法使用！", 'red')
                return
            }
            if (!await checkIsInstalled()) {
                createToast("没有安装猫猫，请先安装！", 'red')
                return
            }
            await runShellWithRoot(`
                        rm /data/data/com.minikano.f50_sms/files/uploads/clash_config.yml
                    `)
            // 检查文件大小
            if (file.size > 1 * 1024 * 1024) {
                createToast(`文件大小不能超过${1}MB！`, 'red')
            } else {
                try {
                    await saveConfig(file)
                } finally {
                    uploadEl.value = ''
                }
            }
        }
    }

    const editBtn = document.createElement('button')
    editBtn.classList.add('btn')
    editBtn.textContent = "编辑配置"
    editBtn.onclick = async () => {
        if (!(await checkAdvanceFunc())) {
            createToast("没有开启高级功能，无法使用！", 'red')
            return
        }
        if (!await checkIsInstalled()) {
            createToast("没有安装猫猫，请先安装！", 'red')
            return
        }
        const res = await runShellWithRoot(`
        timeout 5s  awk '{print}' /data/clash/Proxy/config.yaml
        `)
        if (!res.success) return createToast("备份失败！", 'red')

        const { el, close } = createFixedToast('kano_eidt_mm_message', `
                <div style="pointer-events:all;width:80vw;max-width:800px;">
                    <div class="title" style="margin:0" data-i18n="system_notice">编辑 YAML</div>
                    <div style="margin:10px 0" class="inner"></div>
                    <div style="text-align:right">
                        <button style="font-size:.64rem" id="save_eidt_mm_message_btn" data-i18n="plugin_modal_submit_btn">${t('plugin_modal_submit_btn')}</button>
                        <button style="font-size:.64rem" id="close_eidt_mm_message_btn" data-i18n="close_btn">${t('close_btn')}</button>
                    </div>
                </div>
                `)

        const textarea = document.createElement('textarea')
        textarea.style.width = "100%"
        textarea.style.height = "500px"
        textarea.style.maxHeight = "60vh"
        textarea.style.border = "none"
        textarea.value = res.content
        el.querySelector('.inner').appendChild(textarea)
        const btn = el.querySelector('#close_eidt_mm_message_btn')
        const sbtn = el.querySelector('#save_eidt_mm_message_btn')
        if (!btn) {
            close()
            return
        }
        btn.onclick = async () => {
            close()
        }
        sbtn.onclick = async () => {
            const v = textarea.value
            if (!v || v.trim().length == 0) {
                return createToast("配置不能为空！", 'red')
            }
            createToast("正在保存...", '')
            const file = new File([v], "config.yaml", { type: "text/plain" });
            if (! await saveConfig(file)) { return }
            close()
        }
    }

    const uploadBtn = document.createElement('button')
    uploadBtn.classList.add('btn')
    uploadBtn.textContent = "上传配置"
    uploadBtn.onclick = async () => {
        if (!await checkIsInstalled()) {
            createToast("没有安装猫猫，请先安装！", 'red')
            return
        }
        uploadEl.click()
    }

    const stopBtn = document.createElement('button')
    stopBtn.classList.add('btn')
    stopBtn.textContent = "停止"
    stopBtn.onclick = async () => {
        if (!(await checkAdvanceFunc())) {
            createToast("没有开启高级功能，无法使用！", 'red')
            return
        }
        createToast("干掉猫猫中...", 'green')
        const res = await runShellWithRoot(`
        /data/clash/Scripts/Clash.Service stop
        sleep 1
        `)
        if (!res.success) return createToast("停止失败！", 'red')
        createToast(`<div style="width:300px;text-align:center">
            ${res.content.replaceAll('\n', "<br/>")}
        </div>`, 'green')
        await isMMRunning()
    }

    const backupBtn = document.createElement('button')
    backupBtn.classList.add('btn')
    backupBtn.textContent = "备份配置"
    backupBtn.onclick = async () => {
        if (!(await checkAdvanceFunc())) {
            createToast("没有开启高级功能，无法使用！", 'red')
            return
        }
        if (!await checkIsInstalled()) {
            createToast("没有安装猫猫，请先安装！", 'red')
            return
        }
        createToast("备份猫猫中...", 'green')
        const t = Math.floor(Date.now() + Math.random())
        const res = await runShellWithRoot(`
        rm -f /data/data/com.minikano.f50_sms/files/uploads/mm_config_backup*
        sleep 1
        cp /data/clash/Proxy/config.yaml /data/data/com.minikano.f50_sms/files/uploads/mm_config_backup_${t}.yaml
        chmod 777 /data/data/com.minikano.f50_sms/files/uploads/mm_config_backup_${t}.yaml
        `)
        if (!res.success) return createToast("备份失败！", 'red')
        const a = document.createElement('a')
        a.download = `猫猫配置备份_config_${t}.yaml`
        a.href = `/api/uploads/mm_config_backup_${t}.yaml`
        a.target = "_blank"
        a.style.display = "none"
        document.body.appendChild(a)
        a.click()
        a.remove()
    }

    (async () => {
        const wait = (sec = 100) => new Promise((resolve) => {
            setTimeout(() => {
                resolve()
            }, sec);
        })
        const mmContainer = document.querySelector('.functions-container')
        while (!UFI_DATA.lan_ipaddr) {
            await wait()
        }

        mmContainer.insertAdjacentHTML("afterend", `
<div id="IFRAME_KANO" style="width: 100%; margin-top: 10px;">
    <div class="title" style="margin: 6px 0 ;">
        <strong id="running_mm">猫猫</strong>
        <div style="display: inline-block;" id="collapse_mm_btn"></div>
    </div>
    <div class="collapse" id="collapse_mm" data-name="close" style="height: 0px; overflow: hidden;">
        <div class="collapse_box">
        <div id="mm_action_box" style="margin-bottom:10px;display:flex;gap:10px;flex-wrap:wrap"></div>
            <ul class="deviceList">
<li style="padding:10px">
        <iframe id="mm_iframe" src="javascript:;" style="border:none;padding:0;margin:0;width:100%;height:500px;border-radius: 10px;overflow: hidden;opacity: .6;"></iframe>
</li> </ul>
        </div>
    </div>
</div>
`)
        const refresh = document.createElement('button')
        refresh.classList.add('btn')
        refresh.textContent = "刷新网页"
        refresh.onclick = () => {
            document.getElementById('mm_iframe').src = `http://${UFI_DATA.lan_ipaddr}:7788/ui/?t=` + Date.now();
        }

        const open = document.createElement('button')
        open.classList.add('btn')
        open.textContent = "打开面板"
        open.onclick = () => {
            const a = document.createElement('a')
            a.href = `http://${UFI_DATA.lan_ipaddr}:7788/ui/?t=` + Date.now()
            a.target = "_blank"
            a.style.display = "none"
            document.body.appendChild(a)
            a.click()
            a.remove()
        }

        const wiki = document.createElement('button')
        wiki.classList.add('btn')
        wiki.textContent = "文档教程"
        wiki.onclick = () => {
            const a = document.createElement('a')
            a.href = `https://wiki.metacubex.one/config/`
            a.target = "_blank"
            a.style.display = "none"
            document.body.appendChild(a)
            a.click()
            a.remove()
        }

        const boot_on = document.createElement('button')
        boot_on.id = "clash_boot_on"
        boot_on.classList.add('btn')
        boot_on.textContent = "开机自启"
        boot_on.style.background = ""
        boot_on.addEventListener('click', async () => {
            if (!(await checkAdvanceFunc())) {
                createToast("没有开启高级功能，无法使用！", 'red')
                return
            }
            if (!await checkIsInstalled()) {
                createToast("没有安装猫猫，请先安装！", 'red')
                return
            }
            const isBootUp = await checkIsBootUp();
            if (isBootUp) {
                //关闭
                await runShellWithRoot(`
                sed -i '/Clash.Service/d' /sdcard/ufi_tools_boot.sh
                sed -i '/Clash.Inotify/d' /sdcard/ufi_tools_boot.sh
            `)
                boot_on.style.background = ""
                createToast("已取消开机自启", 'green')
            } else {
                //开启
                await runShellWithRoot(`
                grep -qxF '/data/clash/Scripts/Clash.Service start' /sdcard/ufi_tools_boot.sh || echo '/data/clash/Scripts/Clash.Service start' >> /sdcard/ufi_tools_boot.sh
                grep -qxF 'inotifyd /data/clash/Scripts/Clash.Inotify "/data/clash/Clash" >> /dev/null &' /sdcard/ufi_tools_boot.sh || echo 'inotifyd /data/clash/Scripts/Clash.Inotify "/data/clash/Clash" >> /dev/null &' >> /sdcard/ufi_tools_boot.sh
            `)
                boot_on.style.background = "var(--dark-btn-color-active)"
                createToast("已设置开机自启", 'green')
            }
        })

        checkIsBootUp().then(isBootUp => {
            if (isBootUp) {
                boot_on.style.background = "var(--dark-btn-color-active)"
            } else {
                boot_on.style.background = ""
            }
        })

        if (localStorage.getItem("#collapse_mm") == 'open') {
            refresh.click()
            await isMMRunning()
        }

        const uploadCore = document.createElement('button')
        uploadCore.textContent = "更新内核"
        const uploadCoreInput = document.createElement('input')
        uploadCoreInput.type = 'file'
        uploadCoreInput.accept = '*/*'
        uploadCoreInput.style.display = 'none'

        uploadCoreInput.onchange = async (e) => {
            e.stopPropagation()
            if (!(e.target) || !(e.target.files)) return
            if (e.target.files.length == 0) return
            const file = e.target.files[0];
            if (!file) return
            if (!(await checkAdvanceFunc())) {
                createToast("没有开启高级功能，无法使用！", 'red')
                return
            }
            // 检查文件格式
            if (!await isELF(file)) {
                createToast("只能上传内核二进制文件!", 'red')
                uploadCoreInput.value = ''
                return
            }
            // 检查文件大小
            if (file.size > 50 * 1024 * 1024) {
                createToast(`文件大小不能超过${50}MB！`, 'red')
                uploadCoreInput.value = ''
                return
            }

            const { close } = createFixedToast('upload_core_toast', "上传内核中...")

            // 上传文件
            try {
                const formData = new FormData();
                formData.append("file", file);
                const res = await (await fetch(`${KANO_baseURL}/upload_img`, {
                    method: "POST",
                    headers: common_headers,
                    body: formData,
                })).json()

                if (res.url) {
                    close()
                    let foundFile = await runShellWithRoot(`
                        ls /data/data/com.minikano.f50_sms/files/${res.url}
                    `)
                    if (!foundFile.content) {
                        throw "上传失败"
                    }
                    createToast("上传成功，正在停止内核...", '')
                    stopBtn.click()
                    let resShell = await runShellWithRoot(`
                        rm -f /data/clash/Proxy/Clash.Core
                        mv /data/data/com.minikano.f50_sms/files/${res.url} /data/clash/Proxy/Clash.Core
                        chmod 755 /data/clash/Proxy/Clash.Core
                    `, 120 * 1000)
                    createToast("解压内核...", '')
                    if (resShell.success) {
                        createToast("上传内核完成,正在启动内核...", 'pink')
                        uploadCoreInput.value = ''
                        btn_restart.click()
                        return
                    }
                }
                throw res.error || '上传失败'
            } catch (e) {
                console.error(e);
                createToast(`上传失败!`, 'red')
                uploadCoreInput.value = ''
                return
            } finally {
                close()
            }
        }

        uploadCore.onclick = async () => {
            if (!await checkIsInstalled()) {
                createToast("没有安装猫猫，请先安装！", 'red')
                return
            }
            uploadCoreInput.click()
        }

        const showLogBtn = document.createElement('button')
        showLogBtn.textContent = "查看日志"
        showLogBtn.onclick = async () => {
            if (!checkAdvanceFunc()) {
                return createToast("没有开启高级功能，无法使用！")
            }

            const res = await runShellWithRoot(`
        timeout 2s awk \'{print}\' /sdcard/Clash内核日志.txt
        `)
            if (!res.success) return createToast("获取日志失败！", 'red')
            if (!res.content) return createToast("日志内容为空！", 'red')
            showDialog(res.content, "猫猫日志")
        }

        const mmBox = document.querySelector('#mm_action_box')
        mmBox.appendChild(uploadCoreInput)
        mmBox.appendChild(editBtn)
        mmBox.appendChild(uploadBtn)
        mmBox.appendChild(backupBtn)
        mmBox.appendChild(btn_enabled)
        mmBox.appendChild(stopBtn)
        mmBox.appendChild(btn_restart)
        mmBox.appendChild(btn_disabled)
        mmBox.appendChild(boot_on)
        mmBox.appendChild(open)
        mmBox.appendChild(uploadCore)
        mmBox.appendChild(wiki)
        mmBox.appendChild(showLogBtn)
        mmBox.appendChild(refresh)

        let colTimer = null
        let colTimer1 = null
        collapseGen("#collapse_mm_btn", "#collapse_mm", "#collapse_mm", (e) => {
            checkIsBootUp().then(isBootUp => {
                if (isBootUp) {
                    boot_on.style.background = "var(--dark-btn-color-active)"
                } else {
                    boot_on.style.background = ""
                }
            })
            colTimer && clearTimeout(colTimer)
            colTimer1 && clearTimeout(colTimer1)
            if (e == 'open') {
                colTimer1 = setTimeout(() => {
                    refresh.click()
                }, 300);
            } else {
                colTimer = setTimeout(() => {
                    document.getElementById('mm_iframe').src = `javascript:;`;
                }, 300);
            }
        })
        await isMMRunning()
    })()
})()
//</script >
```

下面是cftunnel插件的代码，记得先把Caddy装好并开启端口，mihomo也要开着。由于后面Caddy端口设置为2944,故在cftunnel那里的已发布应用程序路由应该设置为http://localhost:2944。

拿到token后输入口令，进行一系列操作后执行连接，可以在cftunnel的连接器页面查看状态，是停用的话就代表没连上，正常就表示没问题。有问题可以看日志，问AI。

```javascript
//<script>
(() => {
    // === 核心配置 ===
    const CLASH_PROXY = "http://localhost:7890";

    const CF = {
        DIR: "/data/cloudflared",
        get BIN() { return `${this.DIR}/cloudflared`; },
        get SH() { return `${this.DIR}/startup.sh`; },
        get LOG() { return `${this.DIR}/cloudflared.log`; },
        get TOKEN() { return `${this.DIR}/token.txt`; },
        URL: "https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-arm64"
    };

    const showLogDialog = (content) => {
        const id = 'cf_log_' + Math.random().toString(36).substr(2, 9);
        const { el, close } = createFixedToast(id, `
            <div style="pointer-events:all;width:80vw;max-width:800px">
                <div class="title" style="margin:0">Cloudflare Tunnel 日志</div>
                <div style="margin:10px 0;max-height: 400px;overflow: auto;font-size: .64rem;background:#111;color:#0f0;padding:10px;border-radius:4px;">
                    <pre style="white-space: pre-wrap;word-break: break-all;">${content}</pre>
                </div>
                <div style="text-align:right">
                    <button style="font-size:.64rem" id="close_${id}">关闭</button>
                </div>
            </div>
        `);
        setTimeout(() => {
            const btn = document.getElementById(`close_${id}`);
            if(btn) btn.onclick = close;
        }, 100);
    };

    const Toast = {
        msg: (txt) => createToast(txt, 'green'),
        err: (txt) => createToast(txt, 'red'),
        loading: (txt) => createToast(`⏳ ${txt}`, 'blue', 2000)
    };

    const runRoot = async (cmd) => await runShellWithRoot(cmd);
    
    const getToken = (input) => {
        const m = input?.match(/eyJh[a-zA-Z0-9+/=]+/);
        return m ? m[0] : (input?.length > 50 ? input : null);
    };

    const install = async () => {
        const check = await runRoot(`ls ${CF.BIN}`);
        if(check.success && check.content.includes("cloudflared")) return Toast.msg("已安装");

        Toast.loading("下载组件...");
        await runRoot(`mkdir -p ${CF.DIR} && chmod 777 ${CF.DIR}`);
        const res = await runRoot(`/data/data/com.minikano.f50_sms/files/curl -L "${CF.URL}" -o ${CF.BIN}`, 120000);
        
        if (res.success) {
            await runRoot(`chmod 777 ${CF.BIN}`);
            Toast.msg("安装成功");
        } else {
            Toast.err("下载失败");
        }
    };

    const start = async () => {
        const input = document.getElementById('cf_token').value.trim();
        const token = getToken(input);
        if(!token) {
            const saved = await runRoot(`cat ${CF.TOKEN}`);
            if(!saved.success || !saved.content) return Toast.err("请输入 Token");
        } else {
            await runRoot(`echo "${token}" > ${CF.TOKEN}`);
        }
        
        const finalToken = token || (await runRoot(`cat ${CF.TOKEN}`)).content.trim();

        Toast.loading("启动中...");
        await runRoot(`pkill cloudflared`);
        
        // 生成脚本 (localhost 版)
        const shContent = `#!/system/bin/sh
export http_proxy=${CLASH_PROXY}
export https_proxy=${CLASH_PROXY}
export TUNNEL_HTTP_PROXY=${CLASH_PROXY}
export TUNNEL_TRANSPORT_PROTOCOL=http2
cd ${CF.DIR}
./cloudflared tunnel run --token ${finalToken} > ${CF.LOG} 2>&1 &
`;
        await runRoot(`echo '${shContent}' > ${CF.SH} && chmod 777 ${CF.SH}`);
        await runRoot(`nohup sh ${CF.SH} &`);

        const boot = '/sdcard/ufi_tools_boot.sh';
        await runRoot(`
            sed -i "/cloudflared/d" ${boot}
            sed -i "/startup.sh/d" ${boot}
            echo "nohup sh ${CF.SH} &" >> ${boot}
        `);

        setTimeout(async () => {
             const check = await runRoot(`pgrep cloudflared`);
             if(check.content) Toast.msg("启动成功");
             else Toast.err("启动失败，请看日志");
        }, 2000);
    };

    const logs = async () => {
        Toast.loading("读取日志...");
        const res = await runRoot(`tail -n 100 ${CF.LOG}`);
        
        // === 修复后的智能分析逻辑 ===
        let tips = "";
        const logContent = res.content || "";
        
        // 先转成小写再判断，防止大小写敏感导致的误报
        const lowerLog = logContent.toLowerCase();

        if (lowerLog.includes("registered")) {
            tips = "\n[分析] ✅ 隧道连接成功！(忽略上方可能存在的旧报错)";
        } else if (lowerLog.includes("context deadline exceeded") || lowerLog.includes("i/o timeout") || lowerLog.includes("tls handshake")) {
            tips = "\n[分析] ❌ 连接超时/握手失败 (请检查Clash是否运行，或者重启设备)";
        } else if (lowerLog.includes("error")) {
            tips = "\n[分析] ⚠️ 发现错误日志，请自行检查";
        } else {
            tips = "\n[分析] ⏳ 正在连接或无日志...";
        }
        
        showLogDialog(logContent + tips);
    };

    const init = () => {
        const id = "CF_FINAL_UI_V2";
        if(document.getElementById(id)) document.getElementById(id).remove();

        const container = document.querySelector('.functions-container');
        container.insertAdjacentHTML("afterend", `
        <div id="${id}" style="width: 100%; margin-top: 10px;">
            <div class="title" style="margin: 6px 0;">
                <strong>Cloudflare Tunnel</strong>
                <div style="display: inline-block;" id="collapse_cf_btn"></div>
            </div>
            <div class="collapse" id="collapse_cf" style="height: 0px; overflow: hidden;">
                <div class="collapse_box">
                    <div style="padding:10px;">
                        <textarea id="cf_token" placeholder="在此粘贴 Token (如果是重启可不填)" style="width:100%;background:#222;color:#fff;border:1px solid #444;border-radius:4px;height:50px;font-size:12px;margin-bottom:8px;"></textarea>
                        <div id="cf_btns" style="display:flex; gap:8px; flex-wrap:wrap;"></div>
                    </div>
                </div>
            </div>
        </div>`);

        collapseGen("#collapse_cf_btn", "#collapse_cf", "#collapse_cf", () => {});

        const box = document.getElementById('cf_btns');
        const btn = (t, f, c) => {
            const b = document.createElement('button');
            b.className = 'btn';
            b.textContent = t;
            if(c) b.style.background = c;
            b.onclick = f;
            box.appendChild(b);
        };

        btn("安装", install);
        btn("启动", start);
        btn("停止", async ()=>{ await runRoot('pkill cloudflared'); Toast.msg("已停止"); });
        btn("日志", logs);
        btn("卸载", async ()=>{ 
            await runRoot(`rm -rf ${CF.DIR}`); 
            await runRoot(`sed -i "/cloudflared/d" /sdcard/ufi_tools_boot.sh`);
            Toast.msg("已卸载"); 
        }); 
    };

    init();
})();
//</script>
```

Caddy插件代码如下。
生成测试页面之后，可以访问域名查看有没有成功。主要的阻力在cftunnel那里，这里按步骤操作应该不会出问题。

```javascript
//<script>
(() => {
    const CONFIG = {
        PORT: "2944",
        ROOT_DIR: "/data/myblog",
        INSTALL_DIR: "/data/caddy_server",
        get BIN_PATH() { return `${this.INSTALL_DIR}/caddy`; },
        get LOG_FILE() { return `${this.INSTALL_DIR}/caddy.log`; }
    };

    // 仿猫猫样式的日志弹窗
    const showLogDialog = (title, content) => {
        const id = 'dialog_' + Math.random().toString(36).substr(2, 9);
        const { el, close } = createFixedToast(id, `
            <div style="pointer-events:all;width:80vw;max-width:800px">
                <div class="title" style="margin:0">${title}</div>
                <div style="margin:10px 0;max-height: 400px;overflow: auto;font-size: .64rem;background:#111;color:#eee;padding:10px;border-radius:4px;">
                    <pre style="white-space: pre-wrap;word-break: break-all;">${content}</pre>
                </div>
                <div style="text-align:right">
                    <button style="font-size:.64rem" id="close_${id}">关闭</button>
                </div>
            </div>
        `);
        setTimeout(() => {
            const btn = document.getElementById(`close_${id}`);
            if(btn) btn.onclick = close;
        }, 100);
    };

    const Toast = {
        msg: (txt) => createToast(txt, 'green'),
        err: (txt) => createToast(txt, 'red'),
        loading: (txt) => createToast(`⏳ ${txt}`, 'blue', 2000)
    };

    const runRoot = async (cmd) => await runShellWithRoot(cmd);

    // 安装
    const install = async () => {
        const check = await runRoot(`ls ${CONFIG.BIN_PATH}`);
        if(check.success && check.content.includes("caddy")) return Toast.msg("已安装");

        Toast.loading("下载 Caddy...");
        await runRoot(`mkdir -p ${CONFIG.INSTALL_DIR} && mkdir -p ${CONFIG.ROOT_DIR}`);
        const url = "https://caddyserver.com/api/download?os=linux&arch=arm64";
        const res = await runRoot(`/data/data/com.minikano.f50_sms/files/curl -L "${url}" -o ${CONFIG.BIN_PATH}`, 120000);
        
        if (res.success) {
            await runRoot(`chmod 777 ${CONFIG.BIN_PATH}`);
            Toast.msg("安装成功");
        } else {
            Toast.err("下载失败");
        }
    };

    // 生成测试页 (安全版：目录非空则拦截)
    const genPage = async () => {
        // 安全检查：如果目录里有文件，绝对不覆盖
        const check = await runRoot(`ls -A ${CONFIG.ROOT_DIR}`);
        if(check.success && check.content.trim() !== "") {
            return showLogDialog("安全警告", "⚠️ 你的博客目录 (/data/myblog) 不为空！\n\n为了防止误删你的数据，已拦截操作。\n请手动清空该目录，或者直接上传你的 Hugo 文件。");
        }

        const html = `<!DOCTYPE html><html><body style="text-align:center;padding:50px;"><h1>Caddy Works!</h1><p>Port: ${CONFIG.PORT}</p></body></html>`;
        await runRoot(`echo '${html}' > ${CONFIG.ROOT_DIR}/index.html`);
        Toast.msg("测试页已生成");
    };

    // 启动
    const start = async () => {
        Toast.loading("启动中...");
        await runRoot(`pkill caddy`);
        const cmd = `cd ${CONFIG.INSTALL_DIR} && nohup ./caddy file-server --root ${CONFIG.ROOT_DIR} --listen :${CONFIG.PORT} > ${CONFIG.LOG_FILE} 2>&1 &`;
        await runRoot(cmd);
        
        // 开机自启
        const boot = '/sdcard/ufi_tools_boot.sh';
        await runRoot(`sed -i "/caddy file-server/d" ${boot} && echo "${cmd}" >> ${boot}`);
        
        setTimeout(async () => {
             const check = await runRoot(`pgrep caddy`);
             if(check.content) Toast.msg(`启动成功 :${CONFIG.PORT}`);
             else Toast.err("启动失败");
        }, 1500);
    };

    // 查看日志
    const logs = async () => {
        Toast.loading("读取日志...");
        const res = await runRoot(`tail -n 50 ${CONFIG.LOG_FILE}`);
        showLogDialog("Caddy 日志", res.content || "暂无日志");
    };

    // UI
    const init = () => {
        const id = "CADDY_FINAL_UI";
        if(document.getElementById(id)) document.getElementById(id).remove();

        const container = document.querySelector('.functions-container');
        // 插入到容器之后
        container.insertAdjacentHTML("afterend", `
        <div id="${id}" style="width: 100%; margin-top: 10px;">
            <div class="title" style="margin: 6px 0;">
                <strong>Caddy</strong>
                <div style="display: inline-block;" id="collapse_caddy_btn"></div>
            </div>
            <div class="collapse" id="collapse_caddy" style="height: 0px; overflow: hidden;">
                <div class="collapse_box">
                    <div style="padding:10px;">
                        <div style="font-size:12px;color:#888;margin-bottom:8px;">端口: ${CONFIG.PORT} | 目录: ${CONFIG.ROOT_DIR}</div>
                        <div id="caddy_btns" style="display:flex; gap:8px; flex-wrap:wrap;"></div>
                    </div>
                </div>
            </div>
        </div>`);

        collapseGen("#collapse_caddy_btn", "#collapse_caddy", "#collapse_caddy", () => {});

        const box = document.getElementById('caddy_btns');
        const btn = (t, f, c) => {
            const b = document.createElement('button');
            b.className = 'btn';
            b.textContent = t;
            if(c) b.style.background = c;
            b.onclick = f;
            box.appendChild(b);
        };

        btn("安装", install);
        btn("生成测试页", genPage);
        btn("启动", start); 
        btn("停止", async ()=>{ await runRoot('pkill caddy'); Toast.msg("已停止"); });
        btn("日志", logs);
    };

    init();
})();
//</script>
```

访问blog网址，能看到测试页面的话，就成功啦！
