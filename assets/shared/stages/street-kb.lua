local curState = 0
function onCreate()
    if songName == 'Censory-Overload' then
        precacheImage('hazard/qt-port/stage/streetError')
        precacheImage('hazard/qt-port/stage/streetFrontError')
        precacheImage('hazard/qt-port/stage/streetBackError')

        makeLuaSprite('streetBackError','hazard/qt-port/stage/streetBackError',-750,-145)
        setScrollFactor('streetBackError',0.95,0.95)

        makeLuaSprite('streetError','hazard/qt-port/stage/streetError',-750,-145)
        setProperty('streetError.antialiasing',false)
        setScrollFactor('streetError',0.95,0.95)

        makeLuaSprite('streetFrontError','hazard/qt-port/stage/streetFrontError',-820,710)
        scaleObject('streetFrontError',1.15,1.15)
        setScrollFactor('streetFrontError',0.95,0.95)
    end
    makeLuaSprite('streetBG','hazard/qt-port/stage/streetBack',-750,-145)
    setScrollFactor('streetBG',0.95,0.95)
    addLuaSprite('streetBG',false)

    makeLuaSprite('streetGround','hazard/qt-port/stage/streetFront',-820,720)
    setScrollFactor('streetGround',0.95,0.95)
    scaleObject('streetGround',1.15,1.15)
    setProperty('streetGround.offset.x',0)
    setProperty('streetGround.offset.y',0)
    addLuaSprite('streetGround',false)

    makeAnimatedLuaSprite('streetTv','hazard/qt-port/stage/TV_V5',-62,540)
    addAnimationByPrefix('streetTv','idle','TV_Idle',24,true)
    addAnimationByPrefix('streetTv','eye','TV_brutality',24,true)
    addAnimationByPrefix('streetTv','error','TV_Error',24,true)
    addAnimationByPrefix('streetTv','404','TV_Bluescreen',24,true)
    addAnimationByPrefix('streetTv','alert','TV_Attention',32,false)
    addAnimationByPrefix('streetTv','watch','TV_Watchout',24,true)
    addAnimationByPrefix('streetTv','drop','TV_Drop',24,true)
    addAnimationByPrefix('streetTv','sus','TV_sus',24,true)
    addAnimationByPrefix('streetTv','instructions','TV_Instructions-Normal',24,true)
    addAnimationByPrefix('streetTv','gl','TV_GoodLuck',24,true)
    addAnimationByPrefix('streetTv','heart','TV_End',24,false)
    addAnimationByPrefix('streetTv','eyeRight','TV_eyeRight',24,false)
    addAnimationByPrefix('streetTv','eyeLeft','TV_eyeLeft',24,false)
    setScrollFactor('streetTv',0.9,0.9)
    playAnim('streetTv','idle')
    scaleObject('streetTv',1.2,1.2)
    addLuaSprite('streetTv',false)
    if not lowQuality then
        for gas = 1,2 do
            local names = {'Left','Right'}
            local pos = {{-880,-100},{920,-100}}
            local obName = 'streetGas'..names[gas]
            makeAnimatedLuaSprite(obName,'hazard/qt-port/stage/Gas_Release',pos[gas][1],pos[gas][2])
            scaleObject(obName,2.5,2.5)
            setProperty(obName..'.offset.x',0)
            setProperty(obName..'.offset.y',0)
            addAnimationByPrefix(obName,'burst','Gas_Release',38,false)
            addAnimationByPrefix(obName,'burstALT','Gas_Release',49,false)
            addAnimationByPrefix(obName,'burstFAST','Gas_Release',76,false)
            setProperty(obName..'.alpha',0.001)
            addLuaSprite(obName,true)
            setScrollFactor(obName,0,0)
            if gas == 1 then
                setProperty(obName..'.angle',-31)
            else
                setProperty(obName..'.angle',31)
            end
        end
    end
end
function gasPlayAnim(anim)
    if not lowQuality then
        for gas = 1,2 do
            local dir = {'Left','Right'}
            local name = 'streetGas'..dir[gas]
            objectPlayAnimation(name,anim,true)
            setProperty(name..'.alpha',0.7)
        end
    end
end
function onBeatHit()
    if songName == 'Censory-Overload' then
        if curBeat % 16 == 0 and curBeat >= 80 and curBeat <= 208 then
                gasPlayAnim('burst')
        elseif curBeat >= 304 and curBeat <= 432 then
            triggerEvent('Add Camera Zoom','0.0075','0.015')
            if curBeat % 8 == 0 then
                gasPlayAnim('burstALT')
            end
        elseif curBeat >= 560 and curBeat <= 688 then
            triggerEvent('Add Camera Zoom','0.0075','0.015')
            if curBeat % 4 == 0 then
                gasPlayAnim('burstFAST')
            end
        elseif curBeat >= 832 and curBeat <= 960 then
            triggerEvent('Add Camera Zoom','0.0075','0.015')
            if curBeat % 4 == 2 then
                gasPlayAnim('burstFAST')
            end
        elseif curBeat == 702 then
            gasPlayAnim('burst')
        elseif curBeat == 976 or curBeat == 992 then
            triggerEvent('Add Camera Zoom','0.031','0.062')
        end
    end
end
function onEvent(name,v1,v2)
    if name == 'streetBG state' then
        local state = tonumber(v1)
        if state == nil then
            state = 0
        end
        if curState ~= state then
            if curState == 0 or curState == 1 then
                setProperty('streetBG.alpha',0.001)
                if state ~= 1 then
                    setProperty('streetGround.alpha',0.001)
                end
            elseif curState == 1 then
                removeLuaSprite('streetBackError',false)
            elseif curState == 2 then
                removeLuaSprite('streetError',false)
                removeLuaSprite('streetFrontError',false)
            end
            if state == 0 then
                setProperty('streetBG.alpha',1)
                setProperty('streetGround.alpha',1)
            elseif state == 1 then
                addLuaSprite('streetBackError',false)
                setObjectOrder('streetBackError',getObjectOrder('streetBG'))
            elseif state == 2 then
                addLuaSprite('streetError',false)
                setObjectOrder('streetError',getObjectOrder('streetBG'))
                addLuaSprite('streetFrontError',false)
                setObjectOrder('streetFrontError',getObjectOrder('streetGround'))
            end
            curState = state
        end
    elseif name == 'Gas Effect' then
        local anim = string.lower(v1)
        if anim == 'burstfast' then
            anim = 'burstALT'
        elseif anim == 'burstfaster' then
            anim = 'burstFAST'
        end
        gasPlayAnim(anim)
    elseif name == 'streetTV state' then
        local state = 0
        local anims = {'idle','instructions','gl','alert','watch','eye','error','404','drop','heart','sus'}
        if v1 ~= '' and v1 ~= '0' then
            state = tonumber(v1)
        end
        if state < 1 or state > 8 then
            state = 9
        end
        objectPlayAnimation('streetTv',anims[state],true)
    end
end