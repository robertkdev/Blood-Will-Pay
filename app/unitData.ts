export type ConceptStatus = "reinspect" | "repaired" | "locked";

export type UnitConcept = {
  id: string;
  name: string;
  role: string;
  image: string;
  status: ConceptStatus;
  statusLabel: string;
  sourceLabel: string;
  stage: string;
  sourcePath: string;
  sourceCommit: string;
  sourceDate: string;
  sha256: string;
  width: number;
  height: number;
};

export const unitConcepts: UnitConcept[] = [
  {
    id: "korath",
    name: "Korath",
    role: "Tank",
    image: "/units/korath.png",
    status: "reinspect",
    statusLabel: "Reinspection pending",
    sourceLabel: "Current Phase II master",
    stage: "Phase II candidate",
    sourcePath:
      "assets/concepts/phase2_calibration/korath/korath_master.png",
    sourceCommit: "4b4f2630232155160e43820aac416158816ff346",
    sourceDate: "July 22, 2026",
    sha256:
      "797fe7361cb6864372eaac3e270cf178b7d15b963725c25259f3c54d88b774a3",
    width: 1024,
    height: 1536,
  },
  {
    id: "veyra",
    name: "Veyra",
    role: "Tank",
    image: "/units/veyra.png",
    status: "repaired",
    statusLabel: "Reapproval pending",
    sourceLabel: "Rebuilt Phase II master",
    stage: "Phase II repaired cut",
    sourcePath: "assets/concepts/phase2_calibration/veyra/veyra_master.png",
    sourceCommit: "9d03d7c9c67a11200aa77a8ad1ea4dc800db679a",
    sourceDate: "July 22, 2026",
    sha256:
      "aabad99083a89af926bcd6ad2ef1a6a6d8b8d7873fa5b4716eb8dee3d827da60",
    width: 1122,
    height: 1402,
  },
  {
    id: "cashmere",
    name: "Cashmere",
    role: "Mage",
    image: "/units/cashmere.png",
    status: "repaired",
    statusLabel: "Reapproval pending",
    sourceLabel: "Rebuilt Phase II master",
    stage: "Phase II repaired cut",
    sourcePath:
      "assets/concepts/phase2_calibration/cashmere/cashmere_master.png",
    sourceCommit: "9d03d7c9c67a11200aa77a8ad1ea4dc800db679a",
    sourceDate: "July 22, 2026",
    sha256:
      "f80ba21bebe17067f880b2e44dc203efc7a6751ba5876ba6477a9b105abcd02a",
    width: 1024,
    height: 1536,
  },
  {
    id: "pilfer",
    name: "Pilfer",
    role: "Assassin",
    image: "/units/pilfer.png",
    status: "reinspect",
    statusLabel: "Reinspection pending",
    sourceLabel: "Current Phase II master",
    stage: "Phase II candidate",
    sourcePath:
      "assets/concepts/phase2_calibration/pilfer/pilfer_master.png",
    sourceCommit: "4b4f2630232155160e43820aac416158816ff346",
    sourceDate: "July 22, 2026",
    sha256:
      "7c2d18304b26f8503d1843b2eead432b9fd162ee46ef0f19490da5c99a4d4b1e",
    width: 1023,
    height: 1537,
  },
  {
    id: "nyxa",
    name: "Nyxa",
    role: "Marksman",
    image: "/units/nyxa.png",
    status: "reinspect",
    statusLabel: "Reinspection pending",
    sourceLabel: "Current Phase II master",
    stage: "Phase II candidate",
    sourcePath: "assets/concepts/phase2_calibration/nyxa/nyxa_master.png",
    sourceCommit: "4b4f2630232155160e43820aac416158816ff346",
    sourceDate: "July 22, 2026",
    sha256:
      "49041b874855da4855450660db68598f149a424a8fab44d40a0fec08d2e676d1",
    width: 1024,
    height: 1536,
  },
  {
    id: "creep",
    name: "Creep",
    role: "Assassin",
    image: "/units/creep.png",
    status: "reinspect",
    statusLabel: "Reinspection pending",
    sourceLabel: "Current Phase II master",
    stage: "Phase II candidate",
    sourcePath: "assets/concepts/phase2_calibration/creep/creep_master.png",
    sourceCommit: "f4dc6671854de5acdb27ef2742008d80bfe610de",
    sourceDate: "July 21, 2026",
    sha256:
      "74914b21f3ce70bf65f323ae4b5315c4f206bb5f0a2386263bb8a1dbfffa3020",
    width: 1536,
    height: 1024,
  },
  {
    id: "knoll",
    name: "Knoll",
    role: "Support",
    image: "/units/knoll.png",
    status: "locked",
    statusLabel: "Direction locked",
    sourceLabel: "Foreclosure Press",
    stage: "Stage III redesign direction",
    sourcePath:
      "assets/concepts/phase3_redesign/knoll/knoll_foreclosure_press_selected_direction.png",
    sourceCommit: "a7bacddf1b221015901409ba66870ee6f66b0682",
    sourceDate: "July 23, 2026",
    sha256:
      "25d344c8478f732f4053e8aff13f70aaba3d9060b4b88522d917267effbe1c6e",
    width: 1024,
    height: 1536,
  },
  {
    id: "quillith",
    name: "Quillith",
    role: "Support",
    image: "/units/quillith.png",
    status: "repaired",
    statusLabel: "Reapproval pending",
    sourceLabel: "Rebuilt Phase II master",
    stage: "Phase II repaired cut",
    sourcePath:
      "assets/concepts/phase2_calibration/quillith/quillith_master.png",
    sourceCommit: "9d03d7c9c67a11200aa77a8ad1ea4dc800db679a",
    sourceDate: "July 22, 2026",
    sha256:
      "c0ade3bd7b1e1d61363b629123958f0821308eb4d47eeab1167d8d7a1b9abaa7",
    width: 1023,
    height: 1537,
  },
  {
    id: "kett",
    name: "Kett",
    role: "Brawler",
    image: "/units/kett.png",
    status: "reinspect",
    statusLabel: "Reinspection pending",
    sourceLabel: "Current Phase II master",
    stage: "Phase II candidate",
    sourcePath: "assets/concepts/phase2_calibration/kett/kett_master.png",
    sourceCommit: "4b4f2630232155160e43820aac416158816ff346",
    sourceDate: "July 22, 2026",
    sha256:
      "53e16f7f4ccec0c642264c3ce45f2ca5ac9c4aa64dc16f1d447504001495a426",
    width: 1023,
    height: 1537,
  },
  {
    id: "luna",
    name: "Luna",
    role: "Mage",
    image: "/units/luna.png",
    status: "repaired",
    statusLabel: "Reapproval pending",
    sourceLabel: "Rebuilt Phase II master",
    stage: "Phase II repaired cut",
    sourcePath: "assets/concepts/phase2_calibration/luna/luna_master.png",
    sourceCommit: "9d03d7c9c67a11200aa77a8ad1ea4dc800db679a",
    sourceDate: "July 22, 2026",
    sha256:
      "9436100617222f3f5500715c156793f11b0282cdc95b6b3f767aed2e38b7f836",
    width: 1024,
    height: 1536,
  },
  {
    id: "malachor",
    name: "Malachor",
    role: "Tank",
    image: "/units/malachor.png",
    status: "locked",
    statusLabel: "Direction locked",
    sourceLabel: "Living Siege Cage",
    stage: "Stage III redesign direction",
    sourcePath:
      "assets/concepts/phase3_redesign/malachor/malachor_living_siege_cage_selected_direction.png",
    sourceCommit: "dd546e351e7eb2f38093bb95fadcae2520c6f023",
    sourceDate: "July 23, 2026",
    sha256:
      "9f33a99ca5ba7c2047338409244d7e2048e92ae9da8313efa9f5fac21a6e2d32",
    width: 1024,
    height: 1536,
  },
  {
    id: "sable",
    name: "Sable",
    role: "Marksman",
    image: "/units/sable.png",
    status: "reinspect",
    statusLabel: "Reinspection pending",
    sourceLabel: "Current Phase II master",
    stage: "Phase II candidate",
    sourcePath: "assets/concepts/phase2_calibration/sable/sable_master.png",
    sourceCommit: "4b4f2630232155160e43820aac416158816ff346",
    sourceDate: "July 22, 2026",
    sha256:
      "d079556a5ec2050ff23cab8d8414d1fb3705e231f4c55cedbecde448d53bfd47",
    width: 1024,
    height: 1536,
  },
];
