export type Division = 'axial' | 'appendicular';
export type Bone = { id:string; name:string; count:number; division:Division; location:string; function:string; anchor:[number,number]; label:[number,number]; view?:'front'|'back' };
// Counts are grouped, not one SVG shape per bone. Typical adult convention.
export const BONES: Bone[] = [
 {id:'cranium',name:'Cranium',count:8,division:'axial',location:'Upper skull.',function:'Forms the protective case around the brain.',anchor:[280,66],label:[393,41]},
 {id:'face',name:'Facial bones (excluding mandible)',count:13,division:'axial',location:'Face; the mandible is listed separately.',function:'Form the framework of the face.',anchor:[295,101],label:[393,70],view:'front'},
 {id:'mandible',name:'Mandible',count:1,division:'axial',location:'Lower jaw.',function:'Supports the lower teeth and moves at the jaw joint.',anchor:[280,125],label:[393,99],view:'front'},
 {id:'ossicles',name:'Auditory ossicles',count:6,division:'axial',location:'Three tiny bones in each middle ear; shown as a callout.',function:'Transmit vibrations through the middle ear.',anchor:[318,92],label:[393,128]},
 {id:'hyoid',name:'Hyoid',count:1,division:'axial',location:'Neck, below the mandible; shown schematically.',function:'Supports the tongue and provides muscle attachments.',anchor:[280,147],label:[393,157],view:'front'},
 {id:'vertebrae',name:'Vertebral column',count:26,division:'axial',location:'Backbone, including the adult sacrum and coccyx.',function:'Supports the trunk and surrounds the spinal cord.',anchor:[280,309],label:[393,302]},
 {id:'ribs',name:'Ribs',count:24,division:'axial',location:'Twelve pairs around the chest.',function:'Help protect the heart and lungs.',anchor:[329,240],label:[393,244]},
 {id:'sternum',name:'Sternum',count:1,division:'axial',location:'Midline at the front of the chest.',function:'Forms the anterior centre of the rib cage.',anchor:[280,213],label:[393,215],view:'front'},
 {id:'clavicles',name:'Clavicles',count:2,division:'appendicular',location:'Collarbones at the front of the shoulder girdle.',function:'Help connect the shoulder girdle to the trunk.',anchor:[237,171],label:[36,157],view:'front'},
 {id:'scapulae',name:'Scapulae',count:2,division:'appendicular',location:'Shoulder blades at the back of the chest.',function:'Provide shoulder sockets and muscle attachments.',anchor:[229,204],label:[36,186],view:'back'},
 {id:'humeri',name:'Humeri',count:2,division:'appendicular',location:'One humerus in each upper arm.',function:'Connect the shoulder to the elbow.',anchor:[192,254],label:[36,244]},
 {id:'radii',name:'Radii',count:2,division:'appendicular',location:'Thumb side of each forearm in anatomical position.',function:'Work with the ulnae during forearm rotation.',anchor:[157,359],label:[36,331]},
 {id:'ulnae',name:'Ulnae',count:2,division:'appendicular',location:'Little-finger side of each forearm.',function:'Form a major part of the elbow joint.',anchor:[172,348],label:[36,302]},
 {id:'carpals',name:'Carpals',count:16,division:'appendicular',location:'Eight bones in each wrist.',function:'Form the wrist framework.',anchor:[142,430],label:[36,389]},
 {id:'metacarpals',name:'Metacarpals',count:10,division:'appendicular',location:'Five bones in each palm.',function:'Connect the wrist to the fingers.',anchor:[136,452],label:[36,418]},
 {id:'hand-phalanges',name:'Hand phalanges',count:28,division:'appendicular',location:'Fourteen bones in each hand; two in the thumb, three in each finger.',function:'Form the finger skeleton.',anchor:[124,485],label:[36,447]},
 {id:'hip-bones',name:'Hip bones',count:2,division:'appendicular',location:'Pelvic girdle; the sacrum belongs to the axial skeleton.',function:'Connect the lower limbs to the axial skeleton.',anchor:[245,367],label:[393,360]},
 {id:'femora',name:'Femora',count:2,division:'appendicular',location:'One femur in each thigh.',function:'Transmit load between the hip and knee.',anchor:[241,456],label:[393,447]},
 {id:'patellae',name:'Patellae',count:2,division:'appendicular',location:'Kneecaps at the front of the knee.',function:'Help the knee-extensor mechanism.',anchor:[238,530],label:[393,505],view:'front'},
 {id:'tibiae',name:'Tibiae',count:2,division:'appendicular',location:'Medial, larger bones of the lower legs.',function:'Carry most of the load through the lower leg.',anchor:[245,606],label:[393,563]},
 {id:'fibulae',name:'Fibulae',count:2,division:'appendicular',location:'Slender lateral bones of the lower legs.',function:'Provide muscle attachments and contribute to ankle stability.',anchor:[224,608],label:[36,563]},
 {id:'tarsals',name:'Tarsals',count:14,division:'appendicular',location:'Seven bones in each ankle/hindfoot region.',function:'Form the hindfoot framework.',anchor:[239,699],label:[393,650]},
 {id:'metatarsals',name:'Metatarsals',count:10,division:'appendicular',location:'Five bones in each mid/forefoot.',function:'Connect the tarsals to the toe bones.',anchor:[225,721],label:[393,679]},
 {id:'foot-phalanges',name:'Foot phalanges',count:28,division:'appendicular',location:'Fourteen bones in each foot.',function:'Form the toe skeleton.',anchor:[212,744],label:[393,708]},
];
export const SOURCES = [
 ['Skeletal divisions','https://openstax.org/books/anatomy-and-physiology-2e/pages/7-1-divisions-of-the-skeletal-system'],
 ['Upper limb','https://openstax.org/books/anatomy-and-physiology-2e/pages/8-2-bones-of-the-upper-limb'],
 ['Lower limb','https://openstax.org/books/anatomy-and-physiology-2e/pages/8-4-bones-of-the-lower-limb'],
 ['Thoracic cage','https://openstax.org/books/anatomy-and-physiology-2e/pages/7-4-the-thoracic-cage'],
];
export const EXERCISES = [
 {q:'Classify the skull, ribs, humerus and femur as axial or appendicular.',a:'Skull and ribs: axial. Humerus and femur: appendicular.'},
 {q:'A learner counts 80 axial bones and 126 appendicular bones. Find the total and the difference.',a:'Total = 80 + 126 = 206. Difference = 126 − 80 = 46 bones.'},
 {q:'Why does selecting “Ribs” highlight several shapes?',a:'The selectable region represents 12 pairs, or 24 individual bones. This diagram groups bones for teaching.'},
 {q:'Explain why a hip bone and the sacrum belong to different divisions, although both are in the pelvis.',a:'The hip bones belong to the appendicular pelvic girdle. The sacrum is part of the axial vertebral column.'},
 {q:'Locate the radius and ulna. Which lies on the thumb side in anatomical position?',a:'Both are forearm bones. The radius is on the thumb side; the ulna is on the little-finger side.'},
 {q:'How many phalanges are in one hand? How are they distributed?',a:'14: two in the thumb and three in each of the four fingers.'},
 {q:'Compare the tibia and fibula in position and role.',a:'The tibia is medial and carries most lower-leg load. The fibula is lateral and contributes to attachments and ankle stability.'},
 {q:'Assignment: choose a familiar movement. Name two bones involved and explain why bones alone cannot produce it.',a:'Example: elbow bending involves the humerus, radius and ulna. Muscles generate force; bones act as levers at joints.'},
];
export function challengeBone(index:number) { return BONES[((Math.trunc(index)*7+5)%BONES.length+BONES.length)%BONES.length]; }
