function onCreate()
    makeLuaSprite('streetBG','hazard/qt-port/stage/streetBackCute',-750,-145)
    setScrollFactor('streetBG',0.95,0.95)
    addLuaSprite('streetBG',false)

    makeLuaSprite('streetGround','hazard/qt-port/stage/streetFrontCute',-820,720)
    setScrollFactor('streetGround',0.95,0.95)
    scaleObject('streetGround',1.15,1.15)
    setProperty('streetGround.offset.x',0)
    setProperty('streetGround.offset.y',0)
    addLuaSprite('streetGround',false)

    makeAnimatedLuaSprite('streetTv','hazard/qt-port/stage/TV_V5',-62,540)
    addAnimationByPrefix('streetTv','heart','TV_End',24,false)
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
    addAnimationByPrefix('streetTv','eyeRight','TV_eyeRight',24,false)
    addAnimationByPrefix('streetTv','eyeLeft','TV_eyeLeft',24,false)
    setScrollFactor('streetTv',0.9,0.9)
    scaleObject('streetTv',1.2,1.2)
    addLuaSprite('streetTv',false)
end
function onEvent(name,v1,v2)
    if name == 'streetTV state' then
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
function onBeatHit()
    if getProperty('streetTv.animation.curAnim.name') == 'heart' then
        objectPlayAnimation('streetTv','heart',true)
    end
end