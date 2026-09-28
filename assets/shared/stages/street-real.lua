function onCreate()
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
    setScrollFactor('streetTv',0.9,0.9)
    scaleObject('streetTv',1.2,1.2)
    addLuaSprite('streetTv',false)
    
end