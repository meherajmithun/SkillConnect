import { hashPassword, validatePassword } from "./auth.js";
import { timestamp } from "./validation.js";

export async function seedDemo(db, password) {
  validatePassword(password);
  const hash = await hashPassword(password);
  return db.transaction(async (tx) => {
    const services = [
      ["Electrician", "bolt"],
      ["Web Developer", "code"],
      ["Cleaner", "cleaning_services"],
      ["Graphic Designer", "palette"],
      ["AC Technician", "ac_unit"],
      ["Carpenter", "handyman"],
      ["App Developer", "phone_android"],
      ["Computer Technician", "computer"],
    ];
    for (const [name, icon] of services)
      await tx.query(
        "INSERT INTO categories (name,icon) VALUES (?,?) ON CONFLICT(name) DO NOTHING",
        [name, icon],
      );
    for (const [name, lat, lng] of [
      ["Mirpur", 23.8223, 90.3654],
      ["Dhanmondi", 23.7461, 90.3742],
      ["Uttara", 23.8759, 90.3795],
    ])
      await tx.query(
        "INSERT INTO areas (name,city,latitude,longitude) VALUES (?,?,?,?) ON CONFLICT(name) DO NOTHING",
        [name, "Dhaka", lat, lng],
      );
    for (const [name, days, price] of [
      ["Starter", 1, "100.00"],
      ["Weekly", 7, "300.00"],
      ["Half month", 15, "500.00"],
      ["Monthly", 30, "800.00"],
    ]) {
      if (!(await tx.one("SELECT id FROM packages WHERE name=?", [name])))
        await tx.insert("packages", { name, days, price });
    }
    let customer = await tx.one("SELECT * FROM users WHERE username=?", [
      "customer",
    ]);
    if (!customer)
      customer = await tx.insert("users", {
        username: "customer",
        email: "customer@example.com",
        password: hash,
        first_name: "Nadia",
        last_name: "Rahman",
        phone: "+8801700000000",
        role: "customer",
        created_at: timestamp(),
      });
    const pros = [
      [
        "rahim",
        "Rahim",
        "Uddin",
        "Rahim Electrical Works",
        "Electrician",
        "Wiring, lighting and switchboard repairs.",
        "450.00",
      ],
      [
        "sadia",
        "Sadia",
        "Ahmed",
        "Sadia Web Studio",
        "Web Developer",
        "Thoughtful websites for local businesses.",
        "2500.00",
      ],
      [
        "farzana",
        "Farzana",
        "Islam",
        "Fresh Space Cleaning",
        "Cleaner",
        "Regular cleaning and move-in care for your home.",
        "800.00",
      ],
      [
        "tanim",
        "Tanim",
        "Hasan",
        "Tanim Design Desk",
        "Graphic Designer",
        "Brand identities and practical graphic design.",
        "1200.00",
      ],
      [
        "imran",
        "Imran",
        "Ali",
        "Imran Cooling Services",
        "AC Technician",
        "AC maintenance and installation.",
        "700.00",
      ],
      [
        "karim",
        "Karim",
        "Hossain",
        "Karim Carpentry",
        "Carpenter",
        "Custom shelves, furniture repairs and woodwork.",
        "600.00",
      ],
    ];
    for (const [index, p] of pros.entries()) {
      const [username, first_name, last_name, business, service, bio, price] =
        p;
      if (await tx.one("SELECT id FROM users WHERE username=?", [username]))
        continue;
      const user = await tx.insert("users", {
        username,
        email: `${username}@example.com`,
        password: hash,
        first_name,
        last_name,
        phone: `+880170000000${index + 1}`,
        role: "professional",
        created_at: timestamp(),
      });
      const pro = await tx.insert("professionals", {
        user_id: user.id,
        business_name: business,
        bio,
        skills: service,
        experience_years: index + 4,
        verified: index < 4 ? 1 : 0,
        starting_price: price,
        latitude: 23.79 + index * 0.008,
        longitude: 90.37 + index * 0.004,
        created_at: timestamp(),
      });
      const category = await tx.one("SELECT id FROM categories WHERE name=?", [
          service,
        ]),
        area = await tx.one("SELECT id FROM areas WHERE name=?", ["Mirpur"]);
      await tx.insert("professional_categories", {
        professional_id: pro.id,
        category_id: category.id,
      });
      await tx.insert("professional_areas", {
        professional_id: pro.id,
        area_id: area.id,
      });
      await tx.insert("portfolio", {
        professional_id: pro.id,
        title: "Sample completed project",
        description: bio,
        image: "",
      });
      const booking = await tx.insert("bookings", {
        customer_id: customer.id,
        professional_id: pro.id,
        category_id: category.id,
        area_id: area.id,
        scheduled_at: new Date(Date.now() - 2 * 86400000).toISOString(),
        duration_minutes: 60,
        address: "Demonstration address",
        details: "Completed sample project",
        status: "completed",
        created_at: timestamp(),
        updated_at: timestamp(),
      });
      await tx.insert("reviews", {
        booking_id: booking.id,
        rating: 5,
        comment: "Careful work and clear communication. Sample review.",
        created_at: timestamp(),
      });
    }
  });
}
