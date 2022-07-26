extensions [ gis csv ]
breed [households household]
breed [banks bank]

;---------------Gloabl Variables------------------
globals[
  time
  tract         ;;saptial boundary
  nhhold-n1     ;;household amount in neighborhood 1
  nhhold-n2     ;;household amount in neighborhood 2
  nhhold-n3     ;;household amount in neighborhood 3
  avg-n1         ;;average price in neighborhood 1
  avg-n2         ;;average price in neighborhood 2
  avg-n3         ;;average price in neighborhood 3
  n-buyers       ;;number of buyer
  n-sellers      ;;number of seller
  med-n1
  med-n2
  med-n3
  avg-price     ;;output value per patch avg
  med-price     ;;output value per patch med
  avg-askprice
]

;---------------Patch Attributes---------------
patches-own[
  PID      ;;Polygon ID number
  OID      ;;Object ID
  ntype    ;;neighborhood type, displyaed as different colors in the model
  centroid? ;;if it is the centroid of a polygon
  occupied? ;;if it is occupied by a turtle
  une       ;;unemployment
  num-hhold ;;number of hhold in the tract
  seller-count ;;number of sellers
  nil10
  ni10
  ni15
  ni25
  ni35
  ni50
  ni75
  ni100
  ni150
  nim200
  ;medain house price
  hvl50
  hv50
  hv100
  hv150
  hv200
  hv300
  hv500
  hvm1000
]


;---------------Agent Attributes---------------
households-own[
  ;Genral attribute
  hID        ;;household ID
  hNT        ;;household neighborhood type
  hPoly      ;;household polygonID
  hIncome    ;;household income
  hPrice     ;;house price of current living house
  hBudget    ;;Add an atrribute to check affordable or not, bid price based on budget
  employed?  ;;have job or not
  unafford?  ;;if can afford current house
  year       ;;year on market
  assign?    ;;has been assigned a role or not
             ;Status of trade
  trade?
  flag
  role      ;;0: Regular household; 1: Buyer; 2: Seller
            ;Buyers
  wtp        ;;wellingness to pay more, 0.1 more of their bidprice (2.5 income)
  bidprice   ;;bid price
             ;Sellers
  wta        ;;willingness to accpet, 0.25 more of their askprice
  askprice   ;;ask price
]
banks-own[
  hNT        ;;household neighborhood type
  hPoly      ;;household polygonID
  trade?
  askprice   ;;ask price
  bank?
]

;;************************;;
;;****1 Initialization****;;
;;************************;;
;1.1 Set up
to setup
  clear-all
  set time 0
  ;reset-ticks
  resize-world 0 149 0 149 set-patch-size 5
  ;Load Vector Census Tract Data
  set tract gis:load-dataset "Data/DMA_v1.shp"
  ;set tract gis:load-dataset "Data/test.shp"
end

;1.2 Draw the Doundary and Assign each Polygon ID
to draw
  clear-drawing
  reset-ticks
  gis:set-world-envelope gis:envelope-of (tract)

  ;apply the vetor data attributes to patches
  gis:apply-coverage tract "GEO2010" OID
  gis:apply-coverage tract "NT" ntype
  gis:apply-coverage tract "H_EM_R" une        ;unemployment status
                                               ;number of hhousehold with income info
  gis:apply-coverage tract "H_I_L10K"  nil10
  gis:apply-coverage tract "H_I_10K"   ni10
  gis:apply-coverage tract "H_I_15K"   ni15
  gis:apply-coverage tract "H_I_25K"   ni25
  gis:apply-coverage tract "H_I_35K"   ni35
  gis:apply-coverage tract "H_I_50K"   ni50
  gis:apply-coverage tract "H_I_75K"   ni75
  gis:apply-coverage tract "H_I_100K"  ni100
  gis:apply-coverage tract "H_I_150K"  ni150
  gis:apply-coverage tract "H_I_M200K" nim200
  ;medain house price
  gis:apply-coverage tract "H_V_L50K"  hvl50
  gis:apply-coverage tract "H_V_50K"   hv50
  gis:apply-coverage tract "H_V_100K"  hv100
  gis:apply-coverage tract "H_V_150K"  hv150
  gis:apply-coverage tract "H_V_200K"  hv200
  gis:apply-coverage tract "H_V_300K"  hv300
  gis:apply-coverage tract "H_V_500K"  hv500
  gis:apply-coverage tract "H_V_M1M"   hvm1000

  ;Fill the Ploygon with color
  foreach gis:feature-list-of tract
  [
    feature ->
    if gis:property-value feature "NT" = 1 [ gis:set-drawing-color red    gis:fill feature 2.0]
    if gis:property-value feature "NT" = 2 [ gis:set-drawing-color blue   gis:fill feature 2.0]
    if gis:property-value feature "NT" = 3 [ gis:set-drawing-color green  gis:fill feature 2.0]
  ]

  ;Identify Polygon wit ID number
  let x 1
  foreach gis:feature-list-of tract
  [
    feature ->
    let center-point gis:location-of gis:centroid-of feature
    let x-coordinate item 0 center-point
    let y-coordinate item 1 center-point

    ask patch x-coordinate y-coordinate[
      set PID x
      set centroid? true
    ]
    set x x + 1
  ]

  ;3.1, Create Households
  create-household
  ;3.2 set employment
  set-unemployment
  ;3.3, Set up housdeholds with price and budget
  initialize-hprice
  ;3.3, Households Set Budgets
  set-hBudget
  count-unaffordable
  ;Add Buyers and Sellers
  add-sellers-buyers
  update-global
end

;;************************;;
;;****2 Model Dynamic ****;;
;;************************;;
;2.1 Main Funtion
to go
  update-time
  ;;Main function of trade is in 3.7 of the following section
  ;move-buyers-to-seller-bank
  trade
  update-H-M
  count-unaffordable
  add-sellers-buyers
  update-global
  if time > 0 [do-plot] ;to ignore initial burn-in period, we start plotting after 0 time periods.
  ;tick
  if time = Stop-Time [stop]
end

;;************************;;
;;****3, Functions    ****;;
;;************************;;
;;3.1 Create Households For Initilazation
to create-household
  ask patches with [PID > 0] [set occupied? false ]
  let y 1
  while [y <= 1136] [
    ;neighborhood type
    let ntype1  [ntype]  of patches with  [centroid? = true and PID = y]
    ;household amount
    let nil101  [nil10]  of patches with [centroid? = true and PID = y]
    let ni101   [ni10]   of patches with [centroid? = true and PID = y]
    let ni151   [ni15]   of patches with [centroid? = true and PID = y]
    let ni251   [ni25]   of patches with [centroid? = true and PID = y]
    let ni351   [ni35]   of patches with [centroid? = true and PID = y]
    let ni501   [ni50]   of patches with [centroid? = true and PID = y]
    let ni751   [ni75]   of patches with [centroid? = true and PID = y]
    let ni1001  [ni100]  of patches with [centroid? = true and PID = y]
    let ni1501  [ni150]  of patches with [centroid? = true and PID = y]
    let nim2001 [nim200] of patches with [centroid? = true and PID = y]

    if ntype1 = [1][
      ask patches with [PID = y and occupied? = false][
        let z 1
        let a round (item 0  nil101  * 0.01)
        let b round (item 0  ni101   * 0.01)
        let c round (item 0  ni151   * 0.01)
        let d round (item 0  ni251   * 0.01)
        let f round (item 0  ni351   * 0.01)
        let g round (item 0  ni501   * 0.01)
        let h round (item 0  ni751   * 0.01)
        let i round (item 0  ni1001  * 0.01)
        let j round (item 0  nim2001 * 0.01)


        while [z <= a][sprout 1[
          set breed households
          set hID z
          set hNT 1
          set hPoly y
          set shape "dot"
          set hIncome 0 + random int 10
          set color white
          set size 1
          ask patch-here[set occupied? true]
          set z z + 1
          ]

          while [z <= a + b][sprout 1[
            set breed households
            set hID z
            set hNT 1
            set hPoly y
            set shape "dot"
            set hIncome 10 + random int 5
            set color white
            set size 1
            ask patch-here[set occupied? true]
            set z z + 1
          ]]

          while [z <= a + b + c][sprout 1[
            set breed households
            set hID z
            set hNT 1
            set hPoly y
            set shape "dot"
            set hIncome 15 + random int 10
            set color white
            set size 1
            ask patch-here[set occupied? true]
            set z z + 1
          ]]

          while [z <= a + b + c + d][sprout 1[
            set breed households
            set hID z
            set hNT 1
            set hPoly y
            set shape "dot"
            set hIncome 25 + random int 10
            set color white
            set size 1
            ask patch-here[set occupied? true]
            set z z + 1
          ]]

          while [z <= a + b + c + d + f][sprout 1[
            set breed households
            set hID z
            set hNT 1
            set hPoly y
            set shape "dot"
            set hIncome 25 + random int 10
            set color white
            set size 1
            ask patch-here[set occupied? true]
            set z z + 1
          ]]

          while [z <= a + b + c + d + f + g][sprout 1[
            set breed households
            set hID z
            set hNT 1
            set hPoly y
            set shape "dot"
            set hIncome 35 + random int 15
            set color white
            set size 1
            ask patch-here[set occupied? true]
            set z z + 1
          ]]
          while [z <= a + b + c + d + f + g + h][sprout 1[
            set breed households
            set hID z
            set hNT 1
            set hPoly y
            set shape "dot"
            set hIncome 50 + random int 25
            set color white
            set size 1
            ask patch-here[set occupied? true]
            set z z + 1
          ]]
          while [z <= a + b + c + d + f + g + h][sprout 1[
            set breed households
            set hID z
            set hNT 1
            set hPoly y
            set shape "dot"
            set hIncome 75 + random int 25
            set color white
            set size 1
            ask patch-here[set occupied? true]
            set z z + 1
          ]]

          while [z <= a + b + c + d + f + g + h + i][sprout 1[
            set breed households
            set hID z
            set hNT 1
            set hPoly y
            set shape "dot"
            set hIncome 75 + random int 25
            set color white
            set size 1
            ask patch-here[set occupied? true]
            set z z + 1
          ]]

          while [z <= a + b + c + d + f + g + h + i + j][sprout 1[
            set breed households
            set hID z
            set hNT 1
            set hPoly y
            set shape "dot"
            set hIncome 100 + random int 50
            set color white
            set size 1
            ask patch-here[set occupied? true]
            set z z + 1
          ]]
        ]
    ]]

    if ntype1 = [2][
      ask patches with [PID = y and occupied? = false][
        let z 1
        let a round (item 0  nil101  * 0.01)
        let b round (item 0  ni101   * 0.01)
        let c round (item 0  ni151   * 0.01)
        let d round (item 0  ni251   * 0.01)
        let f round (item 0  ni351   * 0.01)
        let g round (item 0  ni501   * 0.01)
        let h round (item 0  ni751   * 0.01)
        let i round (item 0  ni1001  * 0.01)
        let j round (item 0  nim2001 * 0.01)

        while [z <= a][sprout 1[
          set breed households
          set hID z
          set hNT 2
          set hPoly y
          set shape "dot"
          set hIncome 0 + random int 10
          set color pink
          set size 1
          ask patch-here[set occupied? true]
          set z z + 1
          ]

          while [z <= a + b][sprout 1[
            set breed households
            set hID z
            set hNT 2
            set hPoly y
            set shape "dot"
            set hIncome 10 + random int 5
            set color pink
            set size 1
            ask patch-here[set occupied? true]
            set z z + 1
          ]]

          while [z <= a + b + c][sprout 1[
            set breed households
            set hID z
            set hNT 2
            set hPoly y
            set shape "dot"
            set hIncome 15 + random int 10
            set color pink
            set size 1
            ask patch-here[set occupied? true]
            set z z + 1
          ]]

          while [z <= a + b + c + d][sprout 1[
            set breed households
            set hID z
            set hNT 2
            set hPoly y
            set shape "dot"
            set hIncome 25 + random int 10
            set color pink
            set size 1
            ask patch-here[set occupied? true]
            set z z + 1
          ]]

          while [z <= a + b + c + d + f][sprout 1[
            set breed households
            set hID z
            set hNT 2
            set hPoly y
            set shape "dot"
            set hIncome 25 + random int 10
            set color pink
            set size 1
            ask patch-here[set occupied? true]
            set z z + 1
          ]]

          while [z <= a + b + c + d + f + g][sprout 1[
            set breed households
            set hID z
            set hNT 1
            set hPoly y
            set shape "dot"
            set hIncome 35 + random int 15
            set color pink
            set size 1
            ask patch-here[set occupied? true]
            set z z + 1
          ]]
          while [z <= a + b + c + d + f + g + h][sprout 1[
            set breed households
            set hID z
            set hNT 2
            set hPoly y
            set shape "dot"
            set hIncome 50 + random int 25
            set color pink
            set size 1
            ask patch-here[set occupied? true]
            set z z + 1
          ]]
          while [z <= a + b + c + d + f + g + h][sprout 1[
            set breed households
            set hID z
            set hNT 2
            set hPoly y
            set shape "dot"
            set hIncome 75 + random int 25
            set color pink
            set size 1
            ask patch-here[set occupied? true]
            set z z + 1
          ]]

          while [z <= a + b + c + d + f + g + h + i][sprout 1[
            set breed households
            set hID z
            set hNT 2
            set hPoly y
            set shape "dot"
            set hIncome 75 + random int 25
            set color pink
            set size 1
            ask patch-here[set occupied? true]
            set z z + 1
          ]]

          while [z <= a + b + c + d + f + g + h + i + j][sprout 1[
            set breed households
            set hID z
            set hNT 2
            set hPoly y
            set shape "dot"
            set hIncome 100 + random int 50
            set color pink
            set size 1
            ask patch-here[set occupied? true]
            set z z + 1
          ]]
        ]
    ]]

    if ntype1 = [3][
      ask patches with [PID = y and occupied? = false][
        let z 1
        let a round (item 0  nil101  * 0.01)
        let b round (item 0  ni101   * 0.01)
        let c round (item 0  ni151   * 0.01)
        let d round (item 0  ni251   * 0.01)
        let f round (item 0  ni351   * 0.01)
        let g round (item 0  ni501   * 0.01)
        let h round (item 0  ni751   * 0.01)
        let i round (item 0  ni1001  * 0.01)
        let j round (item 0  nim2001 * 0.01)

        while [z <= a][sprout 1[
          set breed households
          set hID z
          set hNT 3
          set hPoly y
          set shape "dot"
          set hIncome 0 + random int 10
          set color yellow
          set size 1
          ask patch-here[set occupied? true]
          set z z + 1
          ]

          while [z <= a + b][sprout 1[
            set breed households
            set hID z
            set hNT 3
            set hPoly y
            set shape "dot"
            set hIncome 10 + random int 5
            set color yellow
            set size 1
            ask patch-here[set occupied? true]
            set z z + 1
          ]]

          while [z <= a + b + c][sprout 1[
            set breed households
            set hID z
            set hNT 3
            set hPoly y
            set shape "dot"
            set hIncome 15 + random int 10
            set color yellow
            set size 1
            ask patch-here[set occupied? true]
            set z z + 1
          ]]

          while [z <= a + b + c + d][sprout 1[
            set breed households
            set hID z
            set hNT 3
            set hPoly y
            set shape "dot"
            set hIncome 25 + random int 10
            set color yellow
            set size 1
            ask patch-here[set occupied? true]
            set z z + 1
          ]]

          while [z <= a + b + c + d + f][sprout 1[
            set breed households
            set hID z
            set hNT 3
            set hPoly y
            set shape "dot"
            set hIncome 25 + random int 10
            set color yellow
            set size 1
            ask patch-here[set occupied? true]
            set z z + 1
          ]]

          while [z <= a + b + c + d + f + g][sprout 1[
            set breed households
            set hID z
            set hNT 3
            set hPoly y
            set shape "dot"
            set hIncome 35 + random int 15
            set color yellow
            set size 1
            ask patch-here[set occupied? true]
            set z z + 1
          ]]
          while [z <= a + b + c + d + f + g + h][sprout 1[
            set breed households
            set hID z
            set hNT 3
            set hPoly y
            set shape "dot"
            set hIncome 50 + random int 25
            set color yellow
            set size 1
            ask patch-here[set occupied? true]
            set z z + 1
          ]]
          while [z <= a + b + c + d + f + g + h][sprout 1[
            set breed households
            set hID z
            set hNT 3
            set hPoly y
            set shape "dot"
            set hIncome 75 + random int 25
            set color yellow
            set size 1
            ask patch-here[set occupied? true]
            set z z + 1
          ]]

          while [z <= a + b + c + d + f + g + h + i][sprout 1[
            set breed households
            set hID z
            set hNT 3
            set hPoly y
            set shape "dot"
            set hIncome 75 + random int 25
            set color yellow
            set size 1
            ask patch-here[set occupied? true]
            set z z + 1
          ]]

          while [z <= a + b + c + d + f + g + h + i + j][sprout 1[
            set breed households
            set hID z
            set hNT 3
            set hPoly y
            set shape "dot"
            set hIncome 100 + random int 50
            set color yellow
            set size 1
            ask patch-here[set occupied? true]
            set z z + 1
          ]]
        ]
    ]]
    set y y + 1
  ]
end

;3.2 Set up unemployment
to set-unemployment
  ask households [set employed? true]
  let y 1
  while [y <= 1136] [
    ask patches with [PID = y][
      ;empolyment
      let hcount count households-here
      ;show hcount
      if hcount > 0 [
        let une1  [une] of patches with  [centroid? = true and PID = y]
        let tempune precision (item 0 une1 * 0.01) 2
        ;show tempune
        ask n-of (round (hcount * tempune)) households [set employed?  false]
      ]
    ]
    set y y + 1
  ]
end

;3.3 initialize houseprice
to initialize-hprice
  let y 1
  while [y <= 1140][
    ask patches with [PID = y][
      let hcount count households-here
      if hcount > 0 [
        let hvl501   precision (item 0 [hvl50]   of patches with [centroid? = true and PID = y] * 0.01) 2
        let hv501    precision (item 0 [hv50]    of patches with [centroid? = true and PID = y] * 0.01) 2
        let hv1001   precision (item 0 [hv100]   of patches with [centroid? = true and PID = y] * 0.01) 2
        let hv1501   precision (item 0 [hv150]   of patches with [centroid? = true and PID = y] * 0.01) 2
        let hv2001   precision (item 0 [hv200]   of patches with [centroid? = true and PID = y] * 0.01) 2
        let hv3001   precision (item 0 [hv300]   of patches with [centroid? = true and PID = y] * 0.01) 2
        let hv5001   precision (item 0 [hv500]   of patches with [centroid? = true and PID = y] * 0.01) 2
        let hvm10001 precision (item 0 [hvm1000] of patches with [centroid? = true and PID = y] * 0.01) 2
        ask n-of (round (hcount * hvl501)) households with [hPoly = y][set hPrice 0 + random int 50]
        ask n-of (round (hcount * hv501))  households with [hPoly = y][set hPrice 50 + random int 50]
        ask n-of (round (hcount * hv1001)) households with [hPoly = y][set hPrice 100 + random int 50]
        ask n-of (round (hcount * hv1501)) households with [hPoly = y][set hPrice 150 + random int 50]
        ask n-of (round (hcount * hv2001)) households with [hPoly = y][set hPrice 200 + random int 100]
        ask n-of (round (hcount * hv3001)) households with [hPoly = y][set hPrice 300 + random int 200]
        ask n-of (round (hcount * hv5001)) households with [hPoly = y][set hPrice 500 + random int 500]
        ask n-of (round (hcount * hvm10001)) households with [hPoly = y][set hPrice 1000 + random int 200]

        let temp-price-list [hPrice] of households with [hPrice != 0 and hPoly = y]
        if length temp-price-list = 0 [
          let hhold-list households with [hPrice = 0 and hPoly = y]
          ask hhold-list [die]
        ]
        if length temp-price-list = 1
        [
          let hhold-list households with [hPrice = 0 and hPoly = y]
          ask hhold-list [set hPrice item 0 temp-price-list]
        ]
        if length temp-price-list > 1
        [
          let a1 mean [hPrice] of households with [hPrice != 0 and hPoly = y]
          let a2 standard-deviation [hPrice] of households with [hPrice != 0 and hPoly = y]
          let hhold-list households with [hPrice = 0 and hPoly = y]
          ask hhold-list [set hPrice random-normal a1 a2]
        ]
      ]
    ]
    set y y + 1
  ]

end

;3.3 Set the budget for all households
;set budgets
to set-hBudget
  ask households[set hBudget 0.34 * hIncome]
end

;3.4 Count Unafforable Households
;Add Sellers and Buyers based on unaffordable
to count-unaffordable
  ask households with [role = 0][
    if hBudget < 0.074 * hPrice;Cannot afford current then find new house, 8% of the house price
    [
      set unafford? true
      set assign? false
    ]
  ]
end

to add-sellers-buyers
  ;;Sellers
  ask n-of (count households with [unafford? = true] * D-S) households with [unafford? = true][
    set unafford? false
    set assign? true
    set role 2
    set year 0
    set trade? false
    set askprice hPrice
    set wta 0.25
    set size 2
    set shape "square"
  ]
  ;;Buyers
  ask households with [unafford? = true and assign? = false ][
    set unafford? false
    set assign? true
    set role 1
    set year 0
    set trade? false
    set bidprice 2.5 * hIncome  ;set up the max price that the household can afford, bid price is the 2.5times of the income
    ifelse (employed? = true)
    [set wtp 0.1]
    [set wtp 0]
    set shape "star"
  ]

  ask households with [assign? = true]
  [set assign?  false]
end

;3.5 Move buyers to seller and bank
to move-buyers-to-seller-bank
  ask households with [role = 1][
    let bp bidprice
    let sellerset households with [role = 2 and (0.2 * askprice  > (0.7 * bp)) and(0.2 * askprice < ((1 + wtp) * bp))]
    let sellerlist sort households with [role = 2 and (0.2 * askprice  > (0.7 * bp)) and(0.2 * askprice < ((1 + wtp) * bp))]
    ifelse length sellerlist = 0
    [print"sellers not found"]
    [
      ifelse length sellerlist > 0
      [
        ;sort households based on household type
        ;let hnt-list sort-by [[h1 h2] ->  [hNT] of h1 > [hNT] of h2] sellerlist
        let fshhold sellerset with [hNT = 3]
        ifelse any? fshhold
        [move-to one-of fshhold set trade? true set hPoly [pid] of patch-here]
        [
          let cshhold sellerset with[hNT = 2]
          ifelse any? cshhold
          [move-to one-of cshhold set trade? true set hPoly [pid] of patch-here]
          [
            let dthhold sellerset with[hNT = 1]
            if any? dthhold [move-to one-of dthhold set trade? true set hPoly [pid] of patch-here]
          ]
        ]
      ]
      [
        move-to item 0 sellerlist
        set trade? true
      ]
    ]
  ]

  if (HAVE-BANK = true) and (count banks > 0)[
    ask households with [role = 1][
      let bp bidprice
      ;sellerlist
      ;let sellerset households with [role = 2 and (0.2 * askprice  > (0.8 * bp)) and(0.2 * askprice < ((1 + wtp) * bp))]
      ;let sellerlist sort households with [role = 2 and (0.2 * askprice  > (0.8 * bp)) and(0.2 * askprice < ((1 + wtp) * bp))]

      let sellerset households with [role = 2 and (askprice > bp) and (askprice < ((1 + wtp) * bp))]
      let sellerlist sort households with [role = 2 and (askprice > bp) and (askprice < ((1 + wtp) * bp))]
      let bankset banks with [(askprice > bp) and (askprice < (1.1 * bp))]
      let banklist sort banks with [(askprice > bp) and (askprice < (1.1 * bp))]

      ifelse length sellerlist = 0
      [print"move->sellers not found"]
      [
        ifelse length sellerlist > 0
        [
          ;sort households based on household type
          ;let hnt-list sort-by [[h1 h2] ->  [hNT] of h1 > [hNT] of h2] sellerlist
          let fshhold sellerset with [hNT = 3]
          ifelse any? fshhold
          ;find far sub household first
          [move-to one-of fshhold set trade? true]
          ;find far sub bank
          [
            let fsbank bankset with [hNT = 3]
            ifelse any? fsbank
            [move-to one-of fsbank set trade? true set hPoly [pid] of patch-here]
            [
              let cshhold sellerset with[hNT = 2]
              ifelse any? cshhold
              [move-to one-of cshhold set trade? true set hPoly [pid] of patch-here]
              [
                let csbank bankset with [hNT = 2]
                ifelse any? csbank
                [move-to one-of csbank set trade? true set hPoly [pid] of patch-here]
                [
                  let dthhold sellerset with[hNT = 1]
                  ifelse any? dthhold
                  [move-to one-of dthhold set trade? true set hPoly [pid] of patch-here]
                  [
                    let dtbank bankset with [hNT = 1]
                    if any? dtbank
                    [move-to one-of dtbank set trade? true set hPoly [pid] of patch-here]
                  ]
                ]
              ]
            ]
          ]
        ]
        [
          move-to one-of sellerlist
          set trade? true
        ]
      ]
    ]
  ]
end

;3.6 Trade
to trade
  move-buyers-to-seller-bank
  bid
end

;3.6.2 ask seller bid price price with buyer
to bid
  ask households with [role = 2][
    let ap [askprice] of self ;sellers askprice
    let nearbuyers sort households with [(role = 1) and (hPoly = [hPoly] of myself) and (trade? = true)]
    ifelse length nearbuyers > 1
    [print "more than 1 p nuyer"
      let new-buyers sort-by [[b1 b2] ->  [bidprice] of b1 > [bidprice] of b2] nearbuyers
      ask item 0 new-buyers [print "-trade happend" set role 0 set trade? false set hPrice bidprice  set hNT [ntype] of patch-here set hBudget 0.34 * hIncome set size 6]
      ;seller become buyer
      set shape "star"
      set size 1
      set role 1
      set bidprice 2.5 * hIncome
    ]
    [
      ifelse length nearbuyers != 0
      [
        print "only ones buyer"
        ask item 0 nearbuyers [print "-trade happend" set role 0 set trade? false set hPrice bidprice  set hNT [ntype] of patch-here set hBudget 0.34 * hIncome set size 6]
        ;seller become buyer
        set shape "star"
        set size 1
        set role 1
        set bidprice 2.5 * hIncome
      ]
      [print"no buyuers"]
    ]
  ]

  if (HAVE-BANK = true) and (count banks > 0)[
    let sellerset households with [role = 2]
    ;show sellerset
    let bankset banks
    ;show bankset

    let joinset (turtle-set sellerset bankset)
    show joinset

    ask joinset [let ap [askprice] of self ;sellers askprice
      let nearbuyers sort households with [(role = 1) and (hPoly = [hPoly] of myself) and (trade? = true)]
      ifelse length nearbuyers > 1
      [
        print "more than 1 p nuyer"
        let new-buyers sort-by [[b1 b2] ->  [bidprice] of b1 > [bidprice] of b2] nearbuyers
        ask item 0 new-buyers [print "-trade happend" show bidprice set role 0 set trade? false set hPrice bidprice  set hNT [ntype] of patch-here set hBudget 0.34 * hIncome set size 6]
        ;show item 0 new-buyers
        if bank? = true
        [die]
        if role = 2
        [
          ;seller become buyer
          set shape "star"
          set size 1
          set role 1
          set bidprice 2.5 * hIncome
        ]
      ]
      [
        ifelse length nearbuyers != 0
        [
          print "only ones buyer"
          ask item 0 nearbuyers [print "-trade happend" show bidprice set role 0 set trade? false set hPrice bidprice  set hNT [ntype] of patch-here set hBudget 0.34 * hIncome set size 6]
          if bank? = true[die]
          if role = 2
          [
            ;seller become buyer
            set shape "star"
            set size 1
            set role 1
            set bidprice 2.5 * hIncome
          ]
        ]
        [print"no buyuers"]
      ]
    ]
  ]
end

;;**************************;;
;;****4,UPDATA VARIABLES****;;
;;**************************;;
;4.1, UPDATE GLOBAL & Visual
;4.1.1 UPDATE GLOBAL
to update-global
  ifelse HAVE-BANK = true[
    set nhhold-n1 count households with [hNT = 1]
    set nhhold-n2 count households with [hNT = 2]
    set nhhold-n3 count households with [hNT = 3]

    ifelse count banks > 0[
      ;let sum[hPrice] of households with [hNT = 1 and role != 1]
      set avg-n1 (sum[hPrice] of households with [hNT = 1 and role != 1] + sum[askprice] of banks with [hNT = 1]) / (count households with [hNT = 1] + count banks with [hNT = 1])
      set avg-n2 (sum[hPrice] of households with [hNT = 2 and role != 1] + sum[askprice] of banks with [hNT = 2]) / (count households with [hNT = 2] + count banks with [hNT = 2])
      set avg-n3 (sum[hPrice] of households with [hNT = 3 and role != 1] + sum[askprice] of banks with [hNT = 3]) / (count households with [hNT = 3] + count banks with [hNT = 3])

      ;    set med-n1 median [hPrice] of households with [hNT = 1 and role != 1]
      ;    set med-n2 median [hPrice] of households with [hNT = 2 and role != 1]
      ;    set med-n3 median [hPrice] of households with [hNT = 3 and role != 1 and hPrice > 0]
      ;combine two lists and output mdeain
      let price-list-n1 sentence [hPrice] of households with [hNT = 1 and role != 1]  [askprice] of banks with[hNT = 1]
      let price-list-n2 sentence [hPrice] of households with [hNT = 2 and role != 1] [askprice] of banks with[hNT = 2]
      let price-list-n3 sentence [hPrice] of households with [hNT = 3 and role != 1 and hPrice > 0] [askprice] of banks with[hNT = 3]

      set med-n1 median price-list-n1
      set med-n2 median price-list-n2
      set med-n3 median price-list-n3

      let n count households with [role = 2]
      let m count banks

      set avg-askprice (sum [askprice] of households with [role = 2] + sum [askprice] of banks) / (n + m)
    ]
    [
      set avg-n1 sum[hPrice] of households with [hNT = 1 and role != 1]  / count households with [hNT = 1]
      set avg-n2 sum[hPrice] of households with [hNT = 2 and role != 1]  / nhhold-n2
      set avg-n3 sum[hPrice] of households with [hNT = 3 and role != 1]  / count households with [hNT = 3]

      set med-n1 median [hPrice] of households with [hNT = 1 and role != 1]
      set med-n2 median [hPrice] of households with [hNT = 2 and role != 1]
      set med-n3 median [hPrice] of households with [hNT = 3 and role != 1]

      let n count households with [role = 2]
      set avg-askprice sum[askprice] of households with [role = 2] / n
    ]
  ]
  [
    set nhhold-n1 count households with [hNT = 1]
    set nhhold-n2 count households with [hNT = 2]
    set nhhold-n3 count households with [hNT = 3]

    set avg-n1 sum[hPrice] of households with [hNT = 1 and role != 1] / count households with [hNT = 1]
    set avg-n2 sum[hPrice] of households with [hNT = 2 and role != 1] / count households with [hNT = 2]
    set avg-n3 sum[hPrice] of households with [hNT = 3 and role != 1] / count households with [hNT = 3]

    set med-n1 median [hPrice] of households with [hNT = 1 and role != 1]
    set med-n2 median [hPrice] of households with [hNT = 2 and role != 1]
    set med-n3 median [hPrice] of households with [hNT = 3 and role != 1]

    let n count households with [role = 2]
    set avg-askprice sum[askprice] of households with [role = 2] / n
  ]
end

;;4.1.2 UPDATE COLOR
to update-color
  ask households with [hNT = 1 and role != 1][set color white]
  ask households with [hNT = 2 and role != 1][set color pink]
  ask households with [hNT = 3 and role != 1][set color yellow]
end

;4.2 Update hhold(agent) and market(environment)
to update-H-M
  update-household
  update-market
end

;4.2.1 UPDATE Households based on economic
to update-household
  update-color
  update-employment
  update-income
  set-hBudget
  update-year
end

;4.2.1.1 update-employment
to update-employment
  ask households[
    let p random-float 1.0
    if (employed? = true)[if p > 0.7[set employed? false]]
    if (employed? = false)[if p > 0.5[set employed? true]]
  ]
end

;4.2.1.2 Income
to update-income
  ask households
  [
    if (employed? = true)
    [set hIncome hIncome + (ln abs 5 / 100) * hIncome]
    if (employed? = false)
    [set hIncome hIncome - 0.1 * hIncome]
  ]
end

;4,2.1.3 update years on market
to update-year
  ask households with [role != 0][set year year + 1]
end


;4,2.2 update market
to update-market
  update-houseprice
  update-seller-askprice
  if HAVE-BANK = true [update-bank-askprice]
  update-buyer-bidprice
  remove-buyer-seller
  count-unaffordable
  add-sellers-buyers
end

;4.2.2.1 Update Overall Houseprice
to update-houseprice
  ask households
  [
    set hPrice (1 + 0.03) * hPrice
  ]
end

;4.2.2.2 Upadte seller ask price
to update-seller-askprice
  ask households with [role = 2][
    if year >= 1 [
      ifelse askprice > 0[
        set askprice (1 - price-drop-rate / 100) * askprice
      ]
      [
        set askprice 0
      ]
    ]
  ]
end

;4.2.2.3 Baks askprice update
to update-bank-askprice
  ;bank decerease 10% of houseprice each time step, the lowest price will be 1$
  ask banks [
    ifelse askprice > 0[
      set askprice (1 - 2 * price-drop-rate / 100) * askprice
      let tempask askprice
      if tempask <= 0[set askprice 1]
    ]
    [
      set askprice 1
    ]
  ]
end

;4.2.2.4 Buyers bidprice Update
to update-buyer-bidprice
  ask households with [role = 1][
    let new-bidprice 2.5 * hIncome
    if year >= 1 [ifelse employed? = true [set bidprice (1 + random-float wtp) * new-bidprice][set bidprice new-bidprice]]
  ]
end

;4.2.2.5 remove buyer and seller
to remove-buyer-seller
  ;buyer
  ask households with[role  = 1][
    if (year = 3)[die ];remove form the system]
  ]
  ;seller
  if HAVE-BANK = true [create-bank]
end

;4.2.2.6 add banks
to create-bank
  ask households with[role = 2][
    if year >= 5[
      let x [pxcor] of patch-here
      let y [pycor] of patch-here
      let htype hNT
      let hpy hPoly
      let askp askprice
      ask patch x y [sprout-banks 1 [set hNT htype set hPoly hpy set trade? false set askprice askp set bank? true]]
      die
    ]
  ]
end

;4.3 update time
to update-time
  set time time + 1
end

;4.4 create new household
to create-new-households

end

;5.x Do Plot
to do-plot
  set-current-plot "Number of Households in Different Submarket"
  set-current-plot-pen "Downtown"
  plot nhhold-n1
  set-current-plot-pen "City-Sub"
  plot nhhold-n2
  set-current-plot-pen "Far-Sub"
  plot nhhold-n3

  set-current-plot "AVG Price in Different Market"
  set-current-plot-pen "Downtown"
  plot avg-n1
  set-current-plot-pen "City-Sub"
  plot avg-n2
  set-current-plot-pen "Far-Sub"
  plot avg-n3

  set-current-plot "Median Price in Different Market"
  set-current-plot-pen "Downtown"
  plot med-n1
  set-current-plot-pen "City-Sub"
  plot med-n2
  set-current-plot-pen "Far-Sub"
  plot med-n3

  set-current-plot "Verification Plot"
  set-current-plot-pen "Total Households"
  plot count households
  set-current-plot-pen "Bank"
  plot count banks * 5
  set-current-plot-pen "Employed"
  plot count households with [employed? = true]
  set-current-plot-pen "Unemployed"
  plot count households with [employed? = false]
end

;6.0 save each patch's avg and median
to save-csv
  if file-exists? "test-flie.csv"[ file-delete "test-flie.csv" ]
  file-open "test-flie.csv"
  let y 0
  while [y <= 1136] [
    show y
    let n count   households with [hPoly = y]
    ifelse n = 0
    [set avg-price 0]
    [set avg-price sum [hPrice] of households with [hPoly = y] / n]
    let price-list [hPrice] of households with [hPoly = y and hPrice > 0]
    ifelse length price-list = 0
    [set med-price 0]
    [set med-price median price-list]
    let temp (list y avg-price med-price)
    file-print csv:to-row temp

    ;file-print (word item 0 temp ","item 1 temp "," item 2 temp)
    ;file-print (temp)

    set y  y + 1
  ]
  file-close
end
@#$#@#$#@
GRAPHICS-WINDOW
225
10
983
769
-1
-1
5.0
1
10
1
1
1
0
1
1
1
0
149
0
149
1
1
1
Years
30.0

BUTTON
1
10
59
43
NIL
setup
NIL
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

BUTTON
71
11
134
44
NIL
draw\n
NIL
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

MONITOR
19
213
122
258
Tract Amount
count patches with [PID > 0]
17
1
11

MONITOR
1013
522
1118
567
Neighborhood 1
nhhold-n1
17
1
11

MONITOR
1121
521
1226
566
Neighborhood 2
nhhold-n2
17
1
11

MONITOR
1229
521
1334
566
Neighborhood 3
nhhold-n3
17
1
11

MONITOR
15
371
120
416
Total households
count households
17
1
11

BUTTON
147
10
210
43
go
go
NIL
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

PLOT
1402
257
1755
507
AVG Price in Different Market
Time
AVG Houseprice (K)
0.0
10.0
0.0
10.0
true
true
"" ""
PENS
"Downtown" 1.0 0 -2674135 true "" ""
"City-Sub" 1.0 0 -13345367 true "" ""
"Far-Sub" 1.0 0 -13840069 true "" ""

PLOT
998
11
1389
251
Number of Households in Different Submarket
Time
Number of Households
0.0
10.0
0.0
10.0
true
true
"" ""
PENS
"Downtown" 1.0 0 -2674135 true "" ""
"City-Sub" 1.0 0 -13345367 true "" ""
"Far-Sub" 1.0 0 -13840069 true "" ""

BUTTON
4
52
210
85
NIL
go\n
T
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

MONITOR
17
266
122
311
No. Buyer
count households with [role = 1]
17
1
11

MONITOR
132
267
214
312
No. Seller
count households with [role = 2]
17
1
11

SLIDER
9
175
140
208
D-S
D-S
0
1
0.5
0.1
1
NIL
HORIZONTAL

PLOT
997
257
1391
507
Verification Plot
Time
Number of Households
0.0
10.0
0.0
10.0
true
true
"" ""
PENS
"Total Households" 1.0 0 -16777216 true "" ""
"Bank" 1.0 0 -955883 true "" ""
"Employed" 1.0 0 -7500403 true "" ""
"Unemployed" 1.0 0 -2064490 true "" ""

SLIDER
8
136
139
169
price-drop-rate
price-drop-rate
0
20
10.0
1
1
%
HORIZONTAL

MONITOR
130
369
214
414
Employed
count households with [employed? = true]
17
1
11

MONITOR
130
420
212
465
Umemployed
count households with [employed? = false]
17
1
11

PLOT
1402
12
1754
253
Median Price in Different Market
Time
Median Houseprice (K)
0.0
10.0
0.0
10.0
true
true
"" ""
PENS
"Far-Sub" 1.0 0 -13840069 true "" ""
"City-Sub" 1.0 0 -14070903 true "" ""
"Downtown" 1.0 0 -2674135 true "" ""

SWITCH
86
95
212
128
HAVE-BANK
HAVE-BANK
1
1
-1000

MONITOR
130
318
213
363
No. Bank
count banks
17
1
11

BUTTON
6
95
80
128
NIL
save-csv\n
NIL
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

TEXTBOX
6
517
248
636
Yellow : Far-Sub Households\nPink     : City-Sub Households\nWhite   : Downtown Households\n\nDot      : Regular Households\nSquare : Seller Households\nStar      : Buyer Households
14
0.0
1

MONITOR
16
317
122
362
Can not Afford
count households with [unafford? = true]
17
1
11

MONITOR
133
214
213
259
Year
time
17
1
11

INPUTBOX
144
136
213
209
Stop-Time
20.0
1
0
Number

MONITOR
16
421
117
466
AVG-asprice
round avg-askprice
17
1
11

@#$#@#$#@
## CREDITS 

## WHAT IS IT?


## HOW IT WORKS


## HOW TO USE IT

## RELATED MODELS

(models in the NetLogo Models Library and elsewhere which are of related interest)

## REFERENCES
@#$#@#$#@
default
true
0
Polygon -7500403 true true 150 5 40 250 150 205 260 250

airplane
true
0
Polygon -7500403 true true 150 0 135 15 120 60 120 105 15 165 15 195 120 180 135 240 105 270 120 285 150 270 180 285 210 270 165 240 180 180 285 195 285 165 180 105 180 60 165 15

arrow
true
0
Polygon -7500403 true true 150 0 0 150 105 150 105 293 195 293 195 150 300 150

box
false
0
Polygon -7500403 true true 150 285 285 225 285 75 150 135
Polygon -7500403 true true 150 135 15 75 150 15 285 75
Polygon -7500403 true true 15 75 15 225 150 285 150 135
Line -16777216 false 150 285 150 135
Line -16777216 false 150 135 15 75
Line -16777216 false 150 135 285 75

bug
true
0
Circle -7500403 true true 96 182 108
Circle -7500403 true true 110 127 80
Circle -7500403 true true 110 75 80
Line -7500403 true 150 100 80 30
Line -7500403 true 150 100 220 30

butterfly
true
0
Polygon -7500403 true true 150 165 209 199 225 225 225 255 195 270 165 255 150 240
Polygon -7500403 true true 150 165 89 198 75 225 75 255 105 270 135 255 150 240
Polygon -7500403 true true 139 148 100 105 55 90 25 90 10 105 10 135 25 180 40 195 85 194 139 163
Polygon -7500403 true true 162 150 200 105 245 90 275 90 290 105 290 135 275 180 260 195 215 195 162 165
Polygon -16777216 true false 150 255 135 225 120 150 135 120 150 105 165 120 180 150 165 225
Circle -16777216 true false 135 90 30
Line -16777216 false 150 105 195 60
Line -16777216 false 150 105 105 60

car
false
0
Polygon -7500403 true true 300 180 279 164 261 144 240 135 226 132 213 106 203 84 185 63 159 50 135 50 75 60 0 150 0 165 0 225 300 225 300 180
Circle -16777216 true false 180 180 90
Circle -16777216 true false 30 180 90
Polygon -16777216 true false 162 80 132 78 134 135 209 135 194 105 189 96 180 89
Circle -7500403 true true 47 195 58
Circle -7500403 true true 195 195 58

circle
false
0
Circle -7500403 true true 0 0 300

circle 2
false
0
Circle -7500403 true true 0 0 300
Circle -16777216 true false 30 30 240

cow
false
0
Polygon -7500403 true true 200 193 197 249 179 249 177 196 166 187 140 189 93 191 78 179 72 211 49 209 48 181 37 149 25 120 25 89 45 72 103 84 179 75 198 76 252 64 272 81 293 103 285 121 255 121 242 118 224 167
Polygon -7500403 true true 73 210 86 251 62 249 48 208
Polygon -7500403 true true 25 114 16 195 9 204 23 213 25 200 39 123

cylinder
false
0
Circle -7500403 true true 0 0 300

dot
false
0
Circle -7500403 true true 90 90 120

face happy
false
0
Circle -7500403 true true 8 8 285
Circle -16777216 true false 60 75 60
Circle -16777216 true false 180 75 60
Polygon -16777216 true false 150 255 90 239 62 213 47 191 67 179 90 203 109 218 150 225 192 218 210 203 227 181 251 194 236 217 212 240

face neutral
false
0
Circle -7500403 true true 8 7 285
Circle -16777216 true false 60 75 60
Circle -16777216 true false 180 75 60
Rectangle -16777216 true false 60 195 240 225

face sad
false
0
Circle -7500403 true true 8 8 285
Circle -16777216 true false 60 75 60
Circle -16777216 true false 180 75 60
Polygon -16777216 true false 150 168 90 184 62 210 47 232 67 244 90 220 109 205 150 198 192 205 210 220 227 242 251 229 236 206 212 183

fish
false
0
Polygon -1 true false 44 131 21 87 15 86 0 120 15 150 0 180 13 214 20 212 45 166
Polygon -1 true false 135 195 119 235 95 218 76 210 46 204 60 165
Polygon -1 true false 75 45 83 77 71 103 86 114 166 78 135 60
Polygon -7500403 true true 30 136 151 77 226 81 280 119 292 146 292 160 287 170 270 195 195 210 151 212 30 166
Circle -16777216 true false 215 106 30

flag
false
0
Rectangle -7500403 true true 60 15 75 300
Polygon -7500403 true true 90 150 270 90 90 30
Line -7500403 true 75 135 90 135
Line -7500403 true 75 45 90 45

flower
false
0
Polygon -10899396 true false 135 120 165 165 180 210 180 240 150 300 165 300 195 240 195 195 165 135
Circle -7500403 true true 85 132 38
Circle -7500403 true true 130 147 38
Circle -7500403 true true 192 85 38
Circle -7500403 true true 85 40 38
Circle -7500403 true true 177 40 38
Circle -7500403 true true 177 132 38
Circle -7500403 true true 70 85 38
Circle -7500403 true true 130 25 38
Circle -7500403 true true 96 51 108
Circle -16777216 true false 113 68 74
Polygon -10899396 true false 189 233 219 188 249 173 279 188 234 218
Polygon -10899396 true false 180 255 150 210 105 210 75 240 135 240

house
false
0
Rectangle -7500403 true true 45 120 255 285
Rectangle -16777216 true false 120 210 180 285
Polygon -7500403 true true 15 120 150 15 285 120
Line -16777216 false 30 120 270 120

leaf
false
0
Polygon -7500403 true true 150 210 135 195 120 210 60 210 30 195 60 180 60 165 15 135 30 120 15 105 40 104 45 90 60 90 90 105 105 120 120 120 105 60 120 60 135 30 150 15 165 30 180 60 195 60 180 120 195 120 210 105 240 90 255 90 263 104 285 105 270 120 285 135 240 165 240 180 270 195 240 210 180 210 165 195
Polygon -7500403 true true 135 195 135 240 120 255 105 255 105 285 135 285 165 240 165 195

line
true
0
Line -7500403 true 150 0 150 300

line half
true
0
Line -7500403 true 150 0 150 150

pentagon
false
0
Polygon -7500403 true true 150 15 15 120 60 285 240 285 285 120

person
false
0
Circle -7500403 true true 110 5 80
Polygon -7500403 true true 105 90 120 195 90 285 105 300 135 300 150 225 165 300 195 300 210 285 180 195 195 90
Rectangle -7500403 true true 127 79 172 94
Polygon -7500403 true true 195 90 240 150 225 180 165 105
Polygon -7500403 true true 105 90 60 150 75 180 135 105

plant
false
0
Rectangle -7500403 true true 135 90 165 300
Polygon -7500403 true true 135 255 90 210 45 195 75 255 135 285
Polygon -7500403 true true 165 255 210 210 255 195 225 255 165 285
Polygon -7500403 true true 135 180 90 135 45 120 75 180 135 210
Polygon -7500403 true true 165 180 165 210 225 180 255 120 210 135
Polygon -7500403 true true 135 105 90 60 45 45 75 105 135 135
Polygon -7500403 true true 165 105 165 135 225 105 255 45 210 60
Polygon -7500403 true true 135 90 120 45 150 15 180 45 165 90

sheep
false
15
Circle -1 true true 203 65 88
Circle -1 true true 70 65 162
Circle -1 true true 150 105 120
Polygon -7500403 true false 218 120 240 165 255 165 278 120
Circle -7500403 true false 214 72 67
Rectangle -1 true true 164 223 179 298
Polygon -1 true true 45 285 30 285 30 240 15 195 45 210
Circle -1 true true 3 83 150
Rectangle -1 true true 65 221 80 296
Polygon -1 true true 195 285 210 285 210 240 240 210 195 210
Polygon -7500403 true false 276 85 285 105 302 99 294 83
Polygon -7500403 true false 219 85 210 105 193 99 201 83

square
false
0
Rectangle -7500403 true true 30 30 270 270

square 2
false
0
Rectangle -7500403 true true 30 30 270 270
Rectangle -16777216 true false 60 60 240 240

star
false
0
Polygon -7500403 true true 151 1 185 108 298 108 207 175 242 282 151 216 59 282 94 175 3 108 116 108

target
false
0
Circle -7500403 true true 0 0 300
Circle -16777216 true false 30 30 240
Circle -7500403 true true 60 60 180
Circle -16777216 true false 90 90 120
Circle -7500403 true true 120 120 60

tree
false
0
Circle -7500403 true true 118 3 94
Rectangle -6459832 true false 120 195 180 300
Circle -7500403 true true 65 21 108
Circle -7500403 true true 116 41 127
Circle -7500403 true true 45 90 120
Circle -7500403 true true 104 74 152

triangle
false
0
Polygon -7500403 true true 150 30 15 255 285 255

triangle 2
false
0
Polygon -7500403 true true 150 30 15 255 285 255
Polygon -16777216 true false 151 99 225 223 75 224

truck
false
0
Rectangle -7500403 true true 4 45 195 187
Polygon -7500403 true true 296 193 296 150 259 134 244 104 208 104 207 194
Rectangle -1 true false 195 60 195 105
Polygon -16777216 true false 238 112 252 141 219 141 218 112
Circle -16777216 true false 234 174 42
Rectangle -7500403 true true 181 185 214 194
Circle -16777216 true false 144 174 42
Circle -16777216 true false 24 174 42
Circle -7500403 false true 24 174 42
Circle -7500403 false true 144 174 42
Circle -7500403 false true 234 174 42

turtle
true
0
Polygon -10899396 true false 215 204 240 233 246 254 228 266 215 252 193 210
Polygon -10899396 true false 195 90 225 75 245 75 260 89 269 108 261 124 240 105 225 105 210 105
Polygon -10899396 true false 105 90 75 75 55 75 40 89 31 108 39 124 60 105 75 105 90 105
Polygon -10899396 true false 132 85 134 64 107 51 108 17 150 2 192 18 192 52 169 65 172 87
Polygon -10899396 true false 85 204 60 233 54 254 72 266 85 252 107 210
Polygon -7500403 true true 119 75 179 75 209 101 224 135 220 225 175 261 128 261 81 224 74 135 88 99

wheel
false
0
Circle -7500403 true true 3 3 294
Circle -16777216 true false 30 30 240
Line -7500403 true 150 285 150 15
Line -7500403 true 15 150 285 150
Circle -7500403 true true 120 120 60
Line -7500403 true 216 40 79 269
Line -7500403 true 40 84 269 221
Line -7500403 true 40 216 269 79
Line -7500403 true 84 40 221 269

wolf
false
0
Polygon -16777216 true false 253 133 245 131 245 133
Polygon -7500403 true true 2 194 13 197 30 191 38 193 38 205 20 226 20 257 27 265 38 266 40 260 31 253 31 230 60 206 68 198 75 209 66 228 65 243 82 261 84 268 100 267 103 261 77 239 79 231 100 207 98 196 119 201 143 202 160 195 166 210 172 213 173 238 167 251 160 248 154 265 169 264 178 247 186 240 198 260 200 271 217 271 219 262 207 258 195 230 192 198 210 184 227 164 242 144 259 145 284 151 277 141 293 140 299 134 297 127 273 119 270 105
Polygon -7500403 true true -1 195 14 180 36 166 40 153 53 140 82 131 134 133 159 126 188 115 227 108 236 102 238 98 268 86 269 92 281 87 269 103 269 113

x
false
0
Polygon -7500403 true true 270 75 225 30 30 225 75 270
Polygon -7500403 true true 30 75 75 30 270 225 225 270
@#$#@#$#@
NetLogo 6.1.1
@#$#@#$#@
@#$#@#$#@
@#$#@#$#@
<experiments>
  <experiment name="Exp-Vali-DS" repetitions="50" runMetricsEveryStep="true">
    <setup>setup
draw</setup>
    <go>go</go>
    <timeLimit steps="20"/>
    <metric>count households with [hNT = 1]</metric>
    <metric>count households with [hNT = 2]</metric>
    <metric>count households with [hNT = 3]</metric>
    <metric>avg-n1</metric>
    <metric>avg-n2</metric>
    <metric>avg-n3</metric>
    <metric>med-n1</metric>
    <metric>med-n2</metric>
    <metric>med-n3</metric>
    <enumeratedValueSet variable="Stop-Time">
      <value value="20"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="D-S">
      <value value="0.1"/>
      <value value="0.5"/>
      <value value="0.9"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="HAVE-BANK">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="price-drop-rate">
      <value value="5"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="Exp-Ver-Bank-Askprice" repetitions="50" runMetricsEveryStep="true">
    <setup>setup
draw</setup>
    <go>go</go>
    <timeLimit steps="20"/>
    <metric>count households</metric>
    <metric>count households with [role = 1]</metric>
    <metric>count households with [role = 2]</metric>
    <metric>count banks</metric>
    <metric>avg-askprice</metric>
    <enumeratedValueSet variable="Stop-Time">
      <value value="20"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="D-S">
      <value value="0.5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="HAVE-BANK">
      <value value="true"/>
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="price-drop-rate">
      <value value="5"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="EXP-Veri-DS" repetitions="50" runMetricsEveryStep="true">
    <setup>setup
draw</setup>
    <go>go</go>
    <timeLimit steps="1"/>
    <metric>count households with [role = 1]</metric>
    <metric>count households with [role = 2]</metric>
    <enumeratedValueSet variable="Stop-Time">
      <value value="20"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="D-S">
      <value value="0.1"/>
      <value value="0.5"/>
      <value value="0.9"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="HAVE-BANK">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="price-drop-rate">
      <value value="5"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="EXP-Veri-PDR" repetitions="50" runMetricsEveryStep="true">
    <setup>setup
draw</setup>
    <go>go</go>
    <timeLimit steps="20"/>
    <metric>avg-askprice</metric>
    <enumeratedValueSet variable="Stop-Time">
      <value value="20"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="D-S">
      <value value="0.5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="HAVE-BANK">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="price-drop-rate">
      <value value="0"/>
      <value value="5"/>
      <value value="10"/>
    </enumeratedValueSet>
  </experiment>
</experiments>
@#$#@#$#@
@#$#@#$#@
default
0.0
-0.2 0 0.0 1.0
0.0 1 1.0 0.0
0.2 0 0.0 1.0
link direction
true
0
Line -7500403 true 150 150 90 180
Line -7500403 true 150 150 210 180
@#$#@#$#@
0
@#$#@#$#@
